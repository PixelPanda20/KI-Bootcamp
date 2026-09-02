#!/usr/bin/env bash
# =============================================================================
#  Open WebUI kontrolliert aktualisieren
#
#      webui-update.sh              zeigt installierte und festgelegte Version
#      webui-update.sh 0.11.3       aktualisiert auf genau diese Version
#      webui-update.sh --zurueck    letzten Stand wiederherstellen
#
#  Warum ein eigenes Skript und kein "docker compose pull":
#
#  Die Abbild-Kennungen in docker-compose.yml sind absichtlich festgenagelt.
#  Ein blosses "pull" holt deshalb nichts Neues, und ein Wechsel auf :latest
#  wuerde das Pinnen aushebeln - zwei Bauten ergaeben wieder zwei verschiedene
#  Abbilder. Dieses Skript aendert stattdessen die Kennung IN der Compose-Datei.
#  Sie bleibt die einzige Quelle, und der neue Stand ist dokumentiert.
#
#  Open WebUI wandert seine Datenbank beim Hochziehen mit. Ein Rueckschritt auf
#  die alte Version allein genuegt dann nicht mehr - deshalb sichert das Skript
#  die Daten vorher weg und spielt sie beim Scheitern zurueck.
# =============================================================================
set -Eeuo pipefail

COMPOSE="$HOME/bootcamp/docker/docker-compose.yml"
SICHERUNG_DIR="$HOME/bootcamp/daten/webui-sicherungen"
DIENST="ki-bootcamp-webui.service"
BILD="ghcr.io/open-webui/open-webui"

blau()  { printf '\033[1;34m%s\033[0m\n' "$*"; }
gruen() { printf '\033[0;32m%s\033[0m\n' "$*"; }
gelb()  { printf '\033[0;33m%s\033[0m\n' "$*"; }
rot()   { printf '\033[0;31m%s\033[0m\n' "$*"; }

[[ -f "$COMPOSE" ]] || { rot "Nicht gefunden: $COMPOSE"; exit 1; }

# --- Kennung aus der Compose-Datei lesen -------------------------------------
festgelegt() {
    awk '
        $0 == "  open-webui:"        { drin = 1; next }
        drin && /^  [a-z]/           { exit }
        drin && /^[[:space:]]*image:/ {
            sub(/^[[:space:]]*image:[[:space:]]*/, ""); print; exit
        }
    ' "$COMPOSE"
}

laufend() {
    curl -s --max-time 8 http://localhost:3000/api/version 2>/dev/null \
        | sed -n 's/.*"version":"\([^"]*\)".*/\1/p'
}

# --- Existiert die Kennung ueberhaupt? --------------------------------------
# Vor dem Umschreiben pruefen, nicht danach. Ein Tippfehler in der Version
# wuerde sonst eine funktionierende Compose-Datei kaputtmachen und der Container
# beim naechsten Start nicht mehr hochkommen.
gibt_es() {
    local ver="$1" token code
    token="$(curl -s --max-time 15 \
        "https://ghcr.io/token?scope=repository:open-webui/open-webui:pull&service=ghcr.io" \
        | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')"
    [[ -n "$token" ]] || return 2          # keine Verbindung: nicht behaupten, es faehle
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 \
        -H "Authorization: Bearer $token" \
        -H "Accept: application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json" \
        "https://ghcr.io/v2/open-webui/open-webui/manifests/$ver")"
    [[ "$code" == "200" ]]
}

neu_starten() {
    if systemctl --user list-unit-files "$DIENST" >/dev/null 2>&1; then
        systemctl --user restart "$DIENST" >/dev/null 2>&1 && return 0
    fi
    ( cd "$(dirname "$COMPOSE")" && docker compose up -d --force-recreate >/dev/null 2>&1 )
}

gesund() {
    local i
    for i in $(seq 1 40); do            # bis zu 4 Minuten
        [[ "$(docker inspect open-webui --format '{{.State.Health.Status}}' 2>/dev/null)" == "healthy" ]] \
            && return 0
        sleep 6
    done
    return 1
}

daten_sichern() {
    # Kein busybox: das wuerde einen Download voraussetzen und im Kursnetz
    # ohne Internet scheitern. Das Open-WebUI-Abbild liegt ohnehin lokal
    # und bringt tar mit.
    local HELFER; HELFER="$(festgelegt)"
    mkdir -p "$SICHERUNG_DIR"
    local ziel="$SICHERUNG_DIR/webui-$(date +%Y%m%d-%H%M%S)-$1.tar.gz"
    if docker run --rm \
         -v docker_open-webui-data:/daten:ro \
         -v "$SICHERUNG_DIR":/sicherung \
         "$HELFER" tar czf "/sicherung/$(basename "$ziel")" -C /daten . >/dev/null 2>&1; then
        echo "$ziel"
        return 0
    fi
    return 1
}

daten_zurueck() {
    local HELFER; HELFER="$(festgelegt)"
    docker run --rm \
        -v docker_open-webui-data:/daten \
        -v "$(dirname "$1")":/sicherung \
        "$HELFER" sh -c "rm -rf /daten/* /daten/..?* 2>/dev/null; tar xzf /sicherung/$(basename "$1") -C /daten" \
        >/dev/null 2>&1
}

# =============================================================================
#  Ohne Argument: nur berichten
# =============================================================================
if [[ $# -eq 0 ]]; then
    blau "Open WebUI"
    echo "  festgelegt in docker-compose.yml : $(festgelegt)"
    LAEUFT="$(laufend || true)"
    echo "  im laufenden Container           : ${LAEUFT:-nicht erreichbar}"
    echo
    echo "  Aktualisieren:  $(basename "$0") <version>     z. B. 0.11.3"
    echo "  Zurueck:        $(basename "$0") --zurueck"
    echo
    echo "  Welche Versionen es gibt, steht unter:"
    echo "    https://github.com/open-webui/open-webui/releases"
    exit 0
fi

# =============================================================================
#  Rueckschritt
# =============================================================================
if [[ "$1" == "--zurueck" ]]; then
    [[ -f "$COMPOSE.vorher" ]] || { rot "Keine vorherige Fassung vorhanden."; exit 1; }
    cp "$COMPOSE.vorher" "$COMPOSE"
    letzte="$(ls -1t "$SICHERUNG_DIR"/webui-*.tar.gz 2>/dev/null | head -1 || true)"
    if [[ -n "$letzte" ]]; then
        blau "Spiele Daten aus $(basename "$letzte") zurueck …"
        daten_zurueck "$letzte" || gelb "Daten konnten nicht zurueckgespielt werden."
    fi
    neu_starten
    gesund && gruen "Zurueckgesetzt auf $(festgelegt)" || rot "Container wurde nicht gesund."
    exit 0
fi

# =============================================================================
#  Aktualisieren
# =============================================================================
ZIEL="${1#v}"                                  # "v0.11.3" wie "0.11.3" behandeln
ALT="$(festgelegt)"
NEU="$BILD:$ZIEL"

[[ "$ALT" == "$NEU" ]] && { gruen "Bereits auf $ZIEL festgelegt."; exit 0; }

blau "Pruefe, ob $ZIEL in der Registry existiert …"
if gibt_es "$ZIEL"; then
    gruen "  $NEU gefunden"
else
    if [[ $? -eq 2 ]]; then
        rot "Keine Verbindung zur Registry. Netz pruefen, dann erneut versuchen."
    else
        rot "Version $ZIEL gibt es nicht."
        echo "  Verfuegbare Versionen: https://github.com/open-webui/open-webui/releases"
    fi
    exit 1
fi

blau "Sichere die Daten von Open WebUI …"
if SICHERUNG="$(daten_sichern "$(echo "$ALT" | sed 's/.*://')")"; then
    gruen "  $SICHERUNG"
else
    gelb "  Sicherung fehlgeschlagen. Weiter ohne Netz und doppelten Boden? [j/N]"
    read -r a; [[ "${a,,}" == "j" ]] || exit 1
    SICHERUNG=""
fi

cp "$COMPOSE" "$COMPOSE.vorher"
sed -i "s|^\([[:space:]]*image:[[:space:]]*\)$BILD:.*|\1$NEU|" "$COMPOSE"
[[ "$(festgelegt)" == "$NEU" ]] || { rot "Kennung liess sich nicht setzen."; cp "$COMPOSE.vorher" "$COMPOSE"; exit 1; }

blau "Lade $NEU …"
if ! docker pull "$NEU"; then
    rot "Laden fehlgeschlagen."; cp "$COMPOSE.vorher" "$COMPOSE"; exit 1
fi

blau "Starte mit der neuen Fassung …"
neu_starten
if gesund; then
    gruen "Open WebUI laeuft auf $(laufend)"
    echo "  Vorherige Compose-Datei: $COMPOSE.vorher"
    [[ -n "$SICHERUNG" ]] && echo "  Datensicherung:          $SICHERUNG"
    echo "  Rueckweg:                $(basename "$0") --zurueck"
else
    rot "Der Container wurde nicht gesund. Setze zurueck …"
    cp "$COMPOSE.vorher" "$COMPOSE"
    [[ -n "$SICHERUNG" ]] && daten_zurueck "$SICHERUNG"
    neu_starten
    gesund && gelb "Alter Stand $ALT wiederhergestellt." || rot "Auch der alte Stand kam nicht hoch. Protokoll: docker logs open-webui"
    exit 1
fi
