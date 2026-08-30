#!/usr/bin/env bash
# =============================================================================
#  KI-Bootcamp VM — Provisionierung
#  Debian 13 (trixie) mit XFCE, amd64 oder arm64
#
#  Wird normalerweise vom Host aus gestartet:
#      ./setup.sh bootcamp@<ip>
#
#  Direkt in der VM geht auch:
#      cd ~/gast && ./provision.sh 2>&1 | tee ~/provision.log
#
#  Idempotent: nach einem Abbruch einfach erneut starten.
# =============================================================================
set -Eeuo pipefail

HIER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BENUTZER="${SUDO_USER:-$USER}"
HEIM="$(getent passwd "$BENUTZER" | cut -d: -f6)"
WORK="$HEIM/bootcamp"
ARCH="$(dpkg --print-architecture)"
CODENAME="$(. /etc/os-release && echo "${VERSION_CODENAME:-trixie}")"

NODE_MAJOR=22
PYTHON_VERSION=3.12          # bewusst nicht die Systemversion, siehe Abschnitt 4

log()  { printf '\n\033[1;34m▶ %s\033[0m\n' "$*"; }
ok()   { printf '  \033[0;32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[0;33m!\033[0m %s\n' "$*"; }

[[ $EUID -eq 0 ]] && { echo "Nicht als root starten, das Skript ruft sudo selbst auf."; exit 1; }

if ! sudo -v 2>/dev/null; then
    cat <<'EOF'
Der Benutzer hat keine sudo-Rechte.

Das passiert bei Debian, wenn bei der Installation ein Root-Passwort gesetzt
wurde. Dann landet der erste Benutzer nicht in der Gruppe sudo.

Als root nachholen und neu anmelden:
    su -
    apt install -y sudo && /sbin/usermod -aG sudo bootcamp
EOF
    exit 1
fi

# sudo-Zeitstempel über den ganzen Lauf frisch halten
( while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) 2>/dev/null &

# Hypervisor erkennen. Bestimmt nur die Gastwerkzeuge — dank XFCE auf X11
# verhält sich der Rest überall gleich.
HERSTELLER="$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || echo unbekannt)"
case "$HERSTELLER" in
    *VMware*)            HV=vmware     ;;
    *innotek*|*Oracle*)  HV=virtualbox ;;
    *QEMU*|*Apple*)      HV=qemu       ;;
    *)                   HV=unbekannt  ;;
esac

echo "Debian $(cat /etc/debian_version) ($CODENAME), $ARCH, Hypervisor: $HV"

# -----------------------------------------------------------------------------
log "1/11  System, Sprache, Tastatur"
# -----------------------------------------------------------------------------
sudo timedatectl set-timezone Europe/Zurich

# Tastatur Schweizerdeutsch, Systemsprache Englisch. Englisch, weil sich
# Fehlermeldungen so suchen lassen und die Kursunterlagen englisch sind.
sudo sed -i 's/^XKBLAYOUT=.*/XKBLAYOUT="ch"/' /etc/default/keyboard 2>/dev/null || true
sudo setupcon 2>/dev/null || true

sudo sed -i 's/^# *\(en_US.UTF-8\)/\1/; s/^# *\(de_CH.UTF-8\)/\1/' /etc/locale.gen
sudo locale-gen >/dev/null
sudo update-locale LANG=en_US.UTF-8 LC_TIME=de_CH.UTF-8 LC_NUMERIC=de_CH.UTF-8

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get -y upgrade
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential git curl wget ca-certificates gnupg \
    unzip zip jq ripgrep fd-find fzf tree htop tmux vim nano \
    python3 python3-venv python3-pip pipx \
    sqlite3 ffmpeg graphviz pandoc xclip \
    apt-transport-https
ok "Basispakete"

mkdir -p "$WORK"/{projekte,uebungen,daten,scripts,docker}

# -----------------------------------------------------------------------------
log "2/11  Gastwerkzeuge"
# -----------------------------------------------------------------------------
case "$HV" in
    vmware)
        sudo apt-get install -y open-vm-tools open-vm-tools-desktop
        sudo systemctl enable --now open-vm-tools 2>/dev/null || true
        ok "open-vm-tools" ;;
    qemu)
        sudo apt-get install -y spice-vdagent qemu-guest-agent
        sudo systemctl enable --now spice-vdagentd qemu-guest-agent 2>/dev/null || true
        ok "SPICE-Gastwerkzeuge" ;;
    virtualbox)
        sudo apt-get install -y virtualbox-guest-x11 || \
            warn "Guest Additions über das VirtualBox-Menü nachinstallieren"
        ok "VirtualBox-Gastwerkzeuge" ;;
    *)  warn "Hypervisor nicht erkannt, Gastwerkzeuge übersprungen" ;;
esac

# -----------------------------------------------------------------------------
log "3/11  Docker"
# -----------------------------------------------------------------------------
if ! command -v docker >/dev/null 2>&1; then
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg |
        sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/debian $CODENAME stable" |
        sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin
fi
sudo usermod -aG docker "$BENUTZER"
sudo systemctl enable --now docker
ok "$(docker --version | cut -d, -f1), Gruppe ab nächster Anmeldung aktiv"

# lazydocker: alle Container mit Protokollen und Auslastung auf einem Schirm.
# Im Alltag schneller als jede Weboberfläche und kostet nichts, wenn es ruht.
if ! command -v lazydocker >/dev/null 2>&1; then
    curl -sL https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh \
        | DIR="$HEIM/.local/bin" bash >/dev/null 2>&1 \
        && ok "lazydocker" || warn "lazydocker nicht installiert"
fi

# -----------------------------------------------------------------------------
log "4/11  Python-Umgebung mit uv"
# -----------------------------------------------------------------------------
command -v uv >/dev/null 2>&1 || curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="$HEIM/.local/bin:$PATH"

cd "$WORK"
# Python wird auf 3.12 festgenagelt, nicht auf die Systemversion von Debian 13.
# Wheels für onnxruntime, ctranslate2 und einige Agentenbibliotheken hinken der
# jeweils neuesten CPython-Version regelmässig Monate hinterher. uv lädt die
# passende Version selbst, das kostet einmalig rund 30 MB.
[[ -d .venv ]] || uv venv --python "$PYTHON_VERSION" .venv
# shellcheck disable=SC1091
source .venv/bin/activate
uv pip install -r "$HIER/requirements-ai.txt"
python -m ipykernel install --user --name bootcamp --display-name "KI-Bootcamp" >/dev/null
ok "Umgebung unter $WORK/.venv ($(python --version))"

# Modelle vorziehen, damit die VM am Kurstag ohne Netz auskommt. Ohne das lädt
# am Morgen jedes Team gleichzeitig, und das WLAN im Kursraum ist tot.
python - <<'PY' || warn "Embedding-Modell nicht vorgeladen"
from chromadb.utils import embedding_functions
embedding_functions.ONNXMiniLM_L6_V2()(["Aufwaermlauf"])
print("  Embedding-Modell gecacht")
PY
python - <<'PY' || warn "Whisper-Modell nicht vorgeladen"
from faster_whisper import WhisperModel
# "small" ist der Punkt, an dem deutsche Standardsprache zuverlaessig sitzt.
WhisperModel("small", device="cpu", compute_type="int8")
print("  Whisper-Modell gecacht")
PY

# -----------------------------------------------------------------------------
log "5/11  Node.js und promptfoo"
# -----------------------------------------------------------------------------
if ! command -v node >/dev/null 2>&1; then
    if curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | sudo -E bash - 2>/dev/null; then
        sudo apt-get install -y nodejs
    else
        warn "NodeSource nicht verfügbar für $CODENAME, nehme Debian-Paket"
        sudo apt-get install -y nodejs npm
    fi
fi
mkdir -p "$HEIM/.npm-global"
npm config set prefix "$HEIM/.npm-global"
export PATH="$HEIM/.npm-global/bin:$PATH"
npm install -g promptfoo >/dev/null 2>&1 && ok "promptfoo" || warn "promptfoo später nachinstallieren"
ok "Node $(node -v)"

# -----------------------------------------------------------------------------
log "6/11  VS Code und OpenCode"
# -----------------------------------------------------------------------------
if ! command -v code >/dev/null 2>&1; then
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc |
        sudo gpg --dearmor -o /etc/apt/keyrings/packages.microsoft.gpg
    echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/packages.microsoft.gpg] \
https://packages.microsoft.com/repos/code stable main" |
        sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
    sudo apt-get update && sudo apt-get install -y code
fi

# Die IDs der KI-Erweiterungen vor dem Bauen einmal im Marketplace gegenprüfen.
# Sie ändern sich häufiger als die übrigen.
for ext in ms-python.python ms-python.debugpy ms-toolsai.jupyter \
           charliermarsh.ruff ms-azuretools.vscode-docker eamodio.gitlens \
           yzhang.markdown-all-in-one redhat.vscode-yaml Continue.continue; do
    code --install-extension "$ext" --force >/dev/null 2>&1 \
        && ok "Erweiterung $ext" || warn "Erweiterung $ext nicht installiert"
done

command -v opencode >/dev/null 2>&1 || curl -fsSL https://opencode.ai/install | bash
export PATH="$HEIM/.opencode/bin:$PATH"
ok "OpenCode $(opencode --version 2>/dev/null || echo '— Version prüfen')"

# -----------------------------------------------------------------------------
log "7/11  Zugang zu OpenRouter vorbereiten (ohne Schlüssel)"
# -----------------------------------------------------------------------------
mkdir -p "$HEIM/.config/bootcamp" "$HEIM/.config/opencode" "$HEIM/.continue"
[[ -f "$HIER/models.env" ]] && cp "$HIER/models.env" "$HEIM/.config/bootcamp/models.env"

if [[ ! -f "$HEIM/.config/bootcamp/env" ]]; then
    cat >"$HEIM/.config/bootcamp/env" <<'EOF'
# Persoenlicher OpenRouter-Zugang. Wird von bootcamp-setup befuellt.
# NICHT weitergeben, nicht in Git committen.
OPENROUTER_API_KEY=
OPENROUTER_BASE_URL=https://openrouter.ai/api/v1
OPENAI_API_KEY=
OPENAI_BASE_URL=https://openrouter.ai/api/v1
EOF
fi
chmod 600 "$HEIM/.config/bootcamp/env"

cat >"$HEIM/.config/opencode/opencode.json" <<'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "model": "openrouter/anthropic/claude-sonnet-5",
  "provider": {
    "openrouter": { "options": { "apiKey": "{env:OPENROUTER_API_KEY}" } }
  }
}
EOF

cat >"$HEIM/.continue/config.yaml" <<'EOF'
name: BIT KI-Bootcamp
version: 1.0.0
schema: v1
models:
  - name: Sonnet (stark)
    provider: openrouter
    model: anthropic/claude-sonnet-5
    apiKey: ${{ env.OPENROUTER_API_KEY }}
    roles: [chat, edit, apply]
  - name: Gemini Flash (schnell und guenstig)
    provider: openrouter
    model: google/gemini-3.6-flash
    apiKey: ${{ env.OPENROUTER_API_KEY }}
    roles: [chat, autocomplete]
context:
  - provider: file
  - provider: code
  - provider: diff
  - provider: terminal
EOF

grep -q 'config/bootcamp/env' "$HEIM/.bashrc" 2>/dev/null || cat >>"$HEIM/.bashrc" <<'EOF'

# --- KI-Bootcamp ---
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$HOME/.opencode/bin:$PATH"
set -a; [ -f "$HOME/.config/bootcamp/env" ] && . "$HOME/.config/bootcamp/env"; set +a
alias bc='cd ~/bootcamp && source .venv/bin/activate'
alias webui='cd ~/bootcamp/docker && docker compose up -d && xdg-open http://localhost:3000'
alias dockergui='cd ~/bootcamp/docker && docker compose --profile tools up -d && xdg-open http://localhost:9000'
alias lzd='lazydocker'
EOF
ok "OpenCode und Continue konfiguriert, Schlüssel folgt beim ersten Start"

# -----------------------------------------------------------------------------
log "8/11  Dienste vorbereiten"
# -----------------------------------------------------------------------------
cp "$HIER/docker-compose.yml" "$WORK/docker/docker-compose.yml"
sudo -u "$BENUTZER" docker pull ghcr.io/open-webui/open-webui:main 2>/dev/null \
    || docker pull ghcr.io/open-webui/open-webui:main \
    || warn "Open-WebUI-Image nicht vorgezogen, lädt beim ersten Start"
ok "Open WebUI"

# Portainer-Passwort über Datei vorgeben. Sonst verlangt Portainer beim ersten
# Start binnen fünf Minuten ein Konto — eine Frist, die in einem verteilten
# Abbild längst abgelaufen ist. Mindestens zwölf Zeichen sind Pflicht.
printf 'bootcamp2026' > "$HEIM/.config/bootcamp/portainer-admin"
chmod 600 "$HEIM/.config/bootcamp/portainer-admin"
docker pull portainer/portainer-ce:lts >/dev/null 2>&1 \
    && ok "Portainer (docker compose --profile tools up -d)" \
    || warn "Portainer-Image nicht vorgezogen"

# Open WebUI bei jeder Anmeldung starten. Als systemd-Benutzereinheit, damit
# der Dienst nur läuft, wenn auch jemand an der VM arbeitet.
install -m 755 "$HIER/webui-autostart.sh" "$WORK/scripts/webui-autostart.sh" 2>/dev/null || true
if "$WORK/scripts/webui-autostart.sh" an >/dev/null 2>&1; then
    ok "Open WebUI startet künftig automatisch bei der Anmeldung"
else
    # Beim Lauf über SSH fehlt oft die Benutzer-Sitzung von systemd. Die
    # Einheit ist dann geschrieben, greift aber erst nach der nächsten
    # grafischen Anmeldung.
    warn "Autostart vorbereitet, wird bei der nächsten Anmeldung aktiv"
fi

# Bewusst KEIN Ollama. Auf vier CPU-Kernen ohne Grafikbeschleunigung wäre nur
# ein Kleinstmodell lauffähig, und dessen Qualität steht in keinem Verhältnis
# zu dem, was eine ernsthafte On-Premise-Installation leistet. Die Lernenden
# würden daraus den falschen Schluss ziehen, lokale Modelle seien unbrauchbar.
# Spart zudem rund 2 bis 3 GB im Abbild und 1,5 GB Arbeitsspeicher im Betrieb.

# -----------------------------------------------------------------------------
log "9/11  Desktop"
# -----------------------------------------------------------------------------
if [[ -f "$HIER/desktop/wallpaper.jpg" ]]; then
    sudo install -Dm644 "$HIER/desktop/wallpaper.jpg" /usr/share/backgrounds/ki-bootcamp.jpg

    # XFCE benennt die Hintergrundeigenschaft nach dem erkannten Monitor
    # ("monitorVirtual-1", "monitorVMware Virtual Display", ...). Welcher Name
    # es wird, steht zur Provisionierungszeit nicht fest, weil noch keine
    # Sitzung lief. Deshalb setzt ein Autostart-Skript alle vorhandenen
    # Eigenschaften. Idempotent und kostet nichts.
    mkdir -p "$HEIM/.local/bin" "$HEIM/.config/autostart"
    cat >"$HEIM/.local/bin/xfce-anpassen.sh" <<'EOF'
#!/usr/bin/env bash
IMG=/usr/share/backgrounds/ki-bootcamp.jpg
[ -f "$IMG" ] || exit 0
for p in $(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep -E 'last-image$'); do
    xfconf-query -c xfce4-desktop -p "$p" -s "$IMG"
done
for p in $(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep -E 'image-style$'); do
    xfconf-query -c xfce4-desktop -p "$p" -s 5      # 5 = zoomed, füllt ohne Verzerrung
done
xfconf-query -c xsettings -p /Net/ThemeName        -s "Adwaita-dark"     2>/dev/null
xfconf-query -c xsettings -p /Net/IconThemeName    -s "Adwaita"          2>/dev/null
# Bildschirmsperre aus. Ein Lernender, der sich mitten in einer Übung aussperrt
# und das Passwort vergisst, kostet mehr Zeit als die Sperre je schützt.
xfconf-query -c xfce4-screensaver -p /saver/enabled -n -t bool -s false  2>/dev/null
xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/blank-on-ac -n -t int -s 0 2>/dev/null
EOF
    chmod +x "$HEIM/.local/bin/xfce-anpassen.sh"
    cat >"$HEIM/.config/autostart/ki-bootcamp-desktop.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=KI-Bootcamp Desktop
Exec=bash -c "sleep 3; $HOME/.local/bin/xfce-anpassen.sh"
NoDisplay=true
X-GNOME-Autostart-enabled=true
EOF

    # Anmeldebildschirm gleich mit
    if [[ -f /etc/lightdm/lightdm-gtk-greeter.conf ]]; then
        sudo sed -i '/^background=/d' /etc/lightdm/lightdm-gtk-greeter.conf
        sudo sed -i '/^\[greeter\]/a background=/usr/share/backgrounds/ki-bootcamp.jpg' \
            /etc/lightdm/lightdm-gtk-greeter.conf
    fi
    ok "Hintergrundbild und XFCE-Vorgaben"
fi

# Ersteinrichtung beim ersten Anmelden
sudo install -m 755 "$HIER/bootcamp-setup" /usr/local/bin/bootcamp-setup
cat >"$HEIM/.config/autostart/bootcamp-setup.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=KI-Bootcamp Ersteinrichtung
Exec=sh -c 'sleep 5; xfce4-terminal --title="KI-Bootcamp Ersteinrichtung" -e bootcamp-setup'
Terminal=false
X-GNOME-Autostart-enabled=true
EOF
ok "Ersteinrichtung eingerichtet"

# -----------------------------------------------------------------------------
log "10/11  Hilfsskripte"
# -----------------------------------------------------------------------------
cat >"$WORK/scripts/selftest.sh" <<'EOF'
#!/usr/bin/env bash
# Abnahmetest der Bootcamp-VM.
#
# Unterscheidet drei Zustände statt zwei:
#   ✓  in Ordnung
#   ○  noch offen, aber zu diesem Zeitpunkt normal
#   ✗  echter Fehler
#
# Der Unterschied ist wichtig: direkt nach der Provisionierung über SSH sind
# zwei Punkte zwangsläufig offen, weil die Gruppe "docker" erst bei der
# nächsten Anmeldung greift und der Schlüssel erst beim ersten grafischen
# Start abgefragt wird. Das sind keine Fehler.

ok=0; offen=0; fehler=0
JA()   { printf '  \033[0;32m✓\033[0m %s\n' "$1"; ok=$((ok+1)); }
OFFEN(){ printf '  \033[0;33m○\033[0m %s\n     \033[0;33m→ %s\033[0m\n' "$1" "$2"; offen=$((offen+1)); }
NEIN() { printf '  \033[0;31m✗\033[0m %s\n     \033[0;31m→ %s\033[0m\n' "$1" "$2"; fehler=$((fehler+1)); }
chk()  { if eval "$2" >/dev/null 2>&1; then JA "$1"; else NEIN "$1" "${3:-fehlt}"; fi; }

echo "── Werkzeuge ──"
chk "Python"      "python3 --version"
chk "uv"          "command -v uv"
chk "Node"        "command -v node"
chk "Git"         "command -v git"
chk "VS Code"     "command -v code"
chk "OpenCode"    "command -v opencode"
chk "promptfoo"   "command -v promptfoo"      "npm i -g promptfoo"
chk "lazydocker"  "command -v lazydocker"
chk "ffmpeg"      "command -v ffmpeg"         "sudo apt install ffmpeg"

echo "── Docker ──"
# Zuerst der tatsaechliche Zugriff, erst danach die Diagnose. Docker wird auf
# Debian ueber einen Socket aktiviert: docker.socket lauscht, docker.service
# startet beim ersten Zugriff. "systemctl is-active docker" meldet deshalb
# voellig zu Recht "inactive", solange niemand Docker benutzt hat. Wer den
# Dienststatus zuerst prueft, meldet einen Fehler, den es nicht gibt.
if ! command -v docker >/dev/null 2>&1; then
    NEIN "Docker installiert" "Provisionierung erneut laufen lassen"
elif docker info >/dev/null 2>&1; then
    JA "Docker läuft"
else
    MELDUNG="$(docker info 2>&1 >/dev/null | head -3)"
    case "$MELDUNG" in
        *[Pp]ermission\ denied*)
            if id -nG | grep -qw docker; then
                OFFEN "Docker-Zugriff" "Du bist in der Gruppe docker, aber diese Sitzung weiss es noch nicht. Abmelden und neu anmelden, oder für diese Shell: newgrp docker"
            else
                NEIN "Docker-Zugriff" "sudo usermod -aG docker $(id -un), danach neu anmelden"
            fi ;;
        *[Cc]annot\ connect*|*daemon\ running*|*docker.sock*)
            NEIN "Docker-Dienst" "sudo systemctl enable --now docker.service — Ursache zeigt: journalctl -u docker -n 30" ;;
        *)
            NEIN "Docker" "${MELDUNG:-unbekannter Fehler}" ;;
    esac
fi

echo "── Python-Umgebung ──"
if source ~/bootcamp/.venv/bin/activate 2>/dev/null; then
    for m in openai httpx pydantic chromadb streamlit gradio fastapi pandas \
             langchain langgraph smolagents pydantic_ai mcp faster_whisper; do
      chk "import $m" "python -c 'import $m'" "uv pip install $m"
    done
    echo "── Vorgeladene Modelle ──"
    chk "Embeddings gecacht" "python -c \"from chromadb.utils import embedding_functions as e; e.ONNXMiniLM_L6_V2()\""
    chk "Whisper gecacht"    "python -c \"from faster_whisper import WhisperModel as W; W('small', device='cpu', compute_type='int8')\""
else
    NEIN "Virtuelle Umgebung" "~/bootcamp/.venv fehlt, Provisionierung erneut laufen lassen"
fi

echo "── Zugang ──"
set -a; [ -f ~/.config/bootcamp/env ] && . ~/.config/bootcamp/env; set +a
if [ -z "${OPENROUTER_API_KEY:-}" ]; then
    OFFEN "OpenRouter-Schlüssel" "Noch nicht eingetragen. Das ist vor dem ersten grafischen Anmelden normal. Jetzt nachholen: bootcamp-setup"
elif curl -sf -H "Authorization: Bearer $OPENROUTER_API_KEY" https://openrouter.ai/api/v1/key >/dev/null; then
    JA "OpenRouter erreichbar"
else
    NEIN "OpenRouter" "Schlüssel abgelehnt oder kein Netz. Prüfen: bootcamp-setup"
fi

echo "── Dienste ──"
if systemctl --user is-enabled ki-bootcamp-webui.service >/dev/null 2>&1; then
    JA "Open WebUI startet automatisch"
else
    OFFEN "Autostart Open WebUI" "Wird bei der nächsten grafischen Anmeldung aktiv. Sonst: ~/bootcamp/scripts/webui-autostart.sh an"
fi
if curl -sf -o /dev/null http://localhost:3000; then
    JA "Open WebUI antwortet"
else
    OFFEN "Open WebUI" "Läuft noch nicht. Starten mit: webui"
fi

echo
printf '  %d in Ordnung, %d offen, %d Fehler\n' "$ok" "$offen" "$fehler"
if [ "$fehler" -gt 0 ]; then
    echo "  Bitte die roten Punkte beheben."
elif [ "$offen" -gt 0 ]; then
    echo "  Keine Fehler. Die offenen Punkte erledigen sich beim nächsten Anmelden."
else
    echo "  VM ist bereit."
fi
EOF
chmod +x "$WORK/scripts/selftest.sh"

cat >"$WORK/scripts/proxy-setup.sh" <<'EOF'
#!/usr/bin/env bash
# Proxy fuer apt, npm und Docker setzen. Aufruf: ./proxy-setup.sh http://proxy:8080
[ -z "$1" ] && { echo "Aufruf: $0 http://proxy:port"; exit 1; }
P="$1"
echo "Acquire::http::Proxy \"$P\"; Acquire::https::Proxy \"$P\";" | sudo tee /etc/apt/apt.conf.d/95proxy
npm config set proxy "$P"; npm config set https-proxy "$P"
sudo mkdir -p /etc/systemd/system/docker.service.d
printf '[Service]\nEnvironment="HTTP_PROXY=%s"\nEnvironment="HTTPS_PROXY=%s"\nEnvironment="NO_PROXY=localhost,127.0.0.1"\n' "$P" "$P" \
  | sudo tee /etc/systemd/system/docker.service.d/proxy.conf
sudo systemctl daemon-reload && sudo systemctl restart docker
grep -q HTTP_PROXY ~/.bashrc || printf 'export HTTP_PROXY=%s\nexport HTTPS_PROXY=%s\nexport NO_PROXY=localhost,127.0.0.1\n' "$P" "$P" >> ~/.bashrc
echo "Proxy gesetzt. Neue Shell oeffnen."
EOF
chmod +x "$WORK/scripts/proxy-setup.sh"

cp "$HIER/prepare-export.sh" "$HIER/webui-autostart.sh" "$WORK/scripts/" 2>/dev/null || true
[[ -d "$HIER/optional" ]] && cp -a "$HIER/optional/." "$WORK/scripts/"
chmod +x "$WORK"/scripts/*.sh 2>/dev/null || true
ok "Hilfsskripte unter $WORK/scripts/"

# -----------------------------------------------------------------------------
log "11/11  Übungsgerüst"
# -----------------------------------------------------------------------------
cat >"$WORK/uebungen/01_erster_api_call.py" <<'EOF'
"""Uebung 1 — Was ein LLM-Aufruf technisch wirklich ist.

Starten:  bc && python uebungen/01_erster_api_call.py
"""
import os
from openai import OpenAI

client = OpenAI(
    base_url=os.environ["OPENROUTER_BASE_URL"],
    api_key=os.environ["OPENROUTER_API_KEY"],
)

antwort = client.chat.completions.create(
    model="google/gemini-3.6-flash",
    messages=[
        {"role": "system", "content": "Du antwortest knapp und auf Deutsch."},
        {"role": "user", "content": "Erklaere einem Lernenden im 1. Lehrjahr, was ein Token ist."},
    ],
)

print(antwort.choices[0].message.content)
print("\n--- Verbrauch ---")
print(f"Prompt:  {antwort.usage.prompt_tokens} Tokens")
print(f"Antwort: {antwort.usage.completion_tokens} Tokens")
print("\nAufgabe: Wechsle das Modell und vergleiche Qualitaet, Tempo und Tokenzahl.")
EOF

cat >"$WORK/uebungen/README.md" <<'EOF'
# Übungen

Umgebung aktivieren: `bc`

| Datei | Thema |
|---|---|
| `01_erster_api_call.py` | Erster Aufruf gegen OpenRouter, Tokens und Kosten sichtbar machen |

Die übrigen Übungen kommen vom Kursanbieter und werden hier abgelegt.
EOF
ok "Übungsgerüst"

echo
echo "════════════════════════════════════════════════════════════"
echo "  Provisionierung abgeschlossen."
echo
echo "  1) Abmelden und neu anmelden (Docker-Gruppe, Hintergrundbild)"
echo "  2) ~/bootcamp/scripts/selftest.sh"
echo "  3) Vor dem Verteilen: ~/bootcamp/scripts/prepare-export.sh"
echo "════════════════════════════════════════════════════════════"
