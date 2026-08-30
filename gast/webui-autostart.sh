#!/usr/bin/env bash
# =============================================================================
#  Open WebUI automatisch starten
#
#      ~/bootcamp/scripts/webui-autostart.sh an       einschalten
#      ~/bootcamp/scripts/webui-autostart.sh aus      ausschalten
#      ~/bootcamp/scripts/webui-autostart.sh status   nachsehen
#
#  Richtet eine systemd-Benutzereinheit ein, die beim Anmelden
#  "docker compose up -d" ausführt und beim Abmelden wieder herunterfährt.
#
#  Warum eine Benutzereinheit und keine Systemeinheit: Open WebUI wird nur
#  gebraucht, wenn jemand an der VM arbeitet. Ohne Anmeldung ist der Dienst
#  überflüssig und belegt bloss Arbeitsspeicher.
#
#  Warum nicht einfach "restart: unless-stopped" in der Compose-Datei: Das
#  startet einen Container zwar nach einem Neustart wieder, aber nur wenn er
#  vorher schon einmal von Hand angelegt wurde. Beim allerersten Start einer
#  frisch verteilten VM existiert er noch gar nicht.
# =============================================================================
set -Eeuo pipefail

EINHEIT="ki-bootcamp-webui.service"
UNIT_DIR="$HOME/.config/systemd/user"
COMPOSE_DIR="$HOME/bootcamp/docker"

blau()  { printf '\033[1;34m%s\033[0m\n' "$*"; }
gruen() { printf '\033[0;32m%s\033[0m\n' "$*"; }
rot()   { printf '\033[0;31m%s\033[0m\n' "$*"; }

[[ -f "$COMPOSE_DIR/docker-compose.yml" ]] || {
    rot "Keine docker-compose.yml unter $COMPOSE_DIR gefunden."; exit 1; }

einheit_schreiben() {
    mkdir -p "$UNIT_DIR"
    cat >"$UNIT_DIR/$EINHEIT" <<EOF
[Unit]
Description=Open WebUI für das KI-Bootcamp
Documentation=https://github.com/open-webui/open-webui
After=default.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=%h/bootcamp/docker
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
# Beim allerersten Start lädt Docker unter Umständen noch Ebenen nach.
TimeoutStartSec=600

[Install]
WantedBy=default.target
EOF
    systemctl --user daemon-reload
}

case "${1:-status}" in

    an|ein|on|enable)
        einheit_schreiben
        systemctl --user enable --now "$EINHEIT"
        gruen "Open WebUI startet ab jetzt bei jeder Anmeldung."
        echo
        echo "  Adresse:  http://localhost:3000"
        echo "  Ausschalten:  $0 aus"
        echo
        # Der Docker-Dienst des Systems läuft unabhängig davon. Ohne Anmeldung
        # startet Open WebUI nicht — das ist so gewollt. Wer es auch ohne
        # Anmeldung möchte:
        echo "  Auch ohne Anmeldung starten (selten sinnvoll):"
        echo "    sudo loginctl enable-linger $USER"
        ;;

    aus|off|disable)
        systemctl --user disable --now "$EINHEIT" 2>/dev/null || true
        gruen "Automatischer Start ausgeschaltet."
        echo "  Von Hand starten:  webui"
        ;;

    status)
        if systemctl --user is-enabled "$EINHEIT" >/dev/null 2>&1; then
            gruen "Automatischer Start: eingeschaltet"
        else
            blau "Automatischer Start: ausgeschaltet"
        fi
        systemctl --user status "$EINHEIT" --no-pager 2>/dev/null | head -5 || true
        echo
        if curl -sf -o /dev/null http://localhost:3000; then
            gruen "Open WebUI antwortet auf http://localhost:3000"
        else
            blau "Open WebUI antwortet nicht (läuft es schon?)"
        fi
        ;;

    *)
        echo "Aufruf: $0 {an|aus|status}"; exit 1 ;;
esac
