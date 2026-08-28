#!/usr/bin/env bash
# =============================================================================
#  KI-Bootcamp VM — Provisionierung
#  BIT Berufsbildung · Bootcamp 26.-28. Oktober 2026
#
#  Basis:  Xubuntu 24.04.x LTS (XFCE/X11), Benutzer "bootcamp"
#  Start:  ./provision.sh 2>&1 | tee ~/provision.log
#
#  Idempotent: kann nach einem Abbruch erneut gestartet werden.
# =============================================================================
set -Eeuo pipefail

BOOTCAMP_USER="${SUDO_USER:-$USER}"
HOME_DIR="$(getent passwd "$BOOTCAMP_USER" | cut -d: -f6)"
WORK="$HOME_DIR/bootcamp"
NODE_MAJOR=22

# Profil: standard | sparsam  (sparsam = Host mit 8 GB RAM, kein Ollama)
PROFIL="${PROFIL:-standard}"

log()  { printf '\n\033[1;34m▶ %s\033[0m\n' "$*"; }
ok()   { printf '  \033[0;32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[0;33m!\033[0m %s\n' "$*"; }

[[ $EUID -eq 0 ]] && { echo "Nicht als root starten — das Skript ruft sudo selbst auf."; exit 1; }
sudo -v

# -----------------------------------------------------------------------------
log "1/12  Systembasis, Lokalisierung"
# -----------------------------------------------------------------------------
sudo timedatectl set-timezone Europe/Zurich
sudo localectl set-x11-keymap ch || warn "Tastaturlayout manuell auf 'ch' setzen"
# Systemsprache bewusst englisch: Fehlermeldungen sind so suchbar.
sudo locale-gen en_US.UTF-8 de_CH.UTF-8 >/dev/null
sudo update-locale LANG=en_US.UTF-8 LC_TIME=de_CH.UTF-8 LC_NUMERIC=de_CH.UTF-8

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get -y upgrade
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential dkms linux-headers-"$(uname -r)" \
    git curl wget ca-certificates gnupg lsb-release unzip zip \
    python3 python3-venv python3-pip pipx \
    ripgrep fd-find fzf jq yq tree htop tmux nano vim \
    sqlite3 graphviz pandoc \
    software-properties-common apt-transport-https
ok "Basispakete installiert"

# Guest Additions absichern (falls beim ISO-Weg vergessen)
if ! lsmod | grep -q vboxguest; then
    warn "VirtualBox Guest Additions nicht geladen — Clipboard und Auto-Resize fehlen."
    warn "Nachinstallieren: Devices → Insert Guest Additions CD image"
fi

mkdir -p "$WORK"/{projekte,uebungen,daten,scripts,docker}

# -----------------------------------------------------------------------------
log "2/12  uv (Python-Paket- und Umgebungsmanager)"
# -----------------------------------------------------------------------------
if ! command -v uv >/dev/null 2>&1; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi
export PATH="$HOME_DIR/.local/bin:$PATH"
uv --version && ok "uv bereit"

# -----------------------------------------------------------------------------
log "3/12  Node.js ${NODE_MAJOR} LTS"
# -----------------------------------------------------------------------------
if ! command -v node >/dev/null 2>&1 || [[ "$(node -v | cut -c2-3)" -lt $NODE_MAJOR ]]; then
    curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | sudo -E bash -
    sudo apt-get install -y nodejs
fi
# Globale npm-Pakete ohne sudo
mkdir -p "$HOME_DIR/.npm-global"
npm config set prefix "$HOME_DIR/.npm-global"
export PATH="$HOME_DIR/.npm-global/bin:$PATH"

# promptfoo: Prompts und ganze Systeme gegen Testfälle messen, inkl.
# Red-Teaming-Modul. Roter Faden der BIT-Tage 4-6.
npm install -g promptfoo >/dev/null 2>&1 && ok "promptfoo installiert" \
    || warn "promptfoo nicht installiert — später: npm i -g promptfoo"
ok "Node $(node -v)"

# -----------------------------------------------------------------------------
log "3b/12  Firefox als .deb statt Snap"
# -----------------------------------------------------------------------------
# Ubuntu liefert Firefox als Snap. In einer VM startet der spürbar langsam und
# greift schlecht auf das Dateisystem zu — beides stört bei Low-Code-Plattformen
# im Browser, die am Bootcamp Tag 2 gebraucht werden.
if snap list firefox >/dev/null 2>&1; then
    sudo snap remove --purge firefox || true
    sudo install -d -m 0755 /etc/apt/keyrings
    wget -qO- https://packages.mozilla.org/apt/repo-signing-key.gpg |
        sudo tee /etc/apt/keyrings/packages.mozilla.org.asc >/dev/null
    echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] \
https://packages.mozilla.org/apt mozilla main" |
        sudo tee /etc/apt/sources.list.d/mozilla.list >/dev/null
    printf 'Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1000\n' |
        sudo tee /etc/apt/preferences.d/mozilla >/dev/null
    sudo apt-get update && sudo apt-get install -y firefox
fi
ok "Firefox als Systempaket"

# -----------------------------------------------------------------------------
log "4/12  Docker Engine + Compose"
# -----------------------------------------------------------------------------
if ! command -v docker >/dev/null 2>&1; then
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg |
        sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" |
        sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin
fi
sudo usermod -aG docker "$BOOTCAMP_USER"
sudo systemctl enable --now docker
ok "Docker $(docker --version | cut -d, -f1) — Gruppenmitgliedschaft ab nächstem Login aktiv"

# -----------------------------------------------------------------------------
log "5/12  VS Code"
# -----------------------------------------------------------------------------
if ! command -v code >/dev/null 2>&1; then
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc |
        sudo gpg --dearmor -o /etc/apt/keyrings/packages.microsoft.gpg
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/packages.microsoft.gpg] \
https://packages.microsoft.com/repos/code stable main" |
        sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
    sudo apt-get update && sudo apt-get install -y code
fi

# Erweiterungen. Die IDs der KI-Erweiterungen vor dem Build einmal im
# Marketplace gegenprüfen — sie ändern sich häufiger als die übrigen.
VSCODE_EXT=(
    ms-python.python
    ms-python.debugpy
    ms-toolsai.jupyter
    ms-toolsai.vscode-jupyter-cell-tags
    charliermarsh.ruff
    ms-azuretools.vscode-docker
    eamodio.gitlens
    yzhang.markdown-all-in-one
    redhat.vscode-yaml
    tamasfe.even-better-toml
    Continue.continue        # KI-Chat und Autocomplete im Editor
    sst-dev.opencode         # ID vor dem Build verifizieren
)
for ext in "${VSCODE_EXT[@]}"; do
    code --install-extension "$ext" --force >/dev/null 2>&1 \
        && ok "VS-Code-Erweiterung $ext" \
        || warn "Erweiterung $ext nicht installiert — ID prüfen"
done

# -----------------------------------------------------------------------------
log "6/12  OpenCode (Terminal-Agent)"
# -----------------------------------------------------------------------------
if ! command -v opencode >/dev/null 2>&1; then
    curl -fsSL https://opencode.ai/install | bash
fi
export PATH="$HOME_DIR/.opencode/bin:$PATH"
opencode --version && ok "OpenCode bereit"

# -----------------------------------------------------------------------------
log "7/12  Python-Umgebung für die Übungen"
# -----------------------------------------------------------------------------
cd "$WORK"
[[ -d .venv ]] || uv venv --python 3.12 .venv
# shellcheck disable=SC1091
source .venv/bin/activate
uv pip install -r "$HOME_DIR/requirements-ai.txt"
python -m ipykernel install --user --name bootcamp --display-name "KI-Bootcamp" >/dev/null
ok "Virtuelle Umgebung unter $WORK/.venv"

# ChromaDB-Embeddingmodell (ONNX, ~80 MB) vorziehen, damit Tag 1 offline läuft
python - <<'PY' || warn "Embedding-Modell konnte nicht vorgeladen werden"
import chromadb
from chromadb.utils import embedding_functions
ef = embedding_functions.ONNXMiniLM_L6_V2()
ef(["Aufwaermlauf, damit das Modell im Image liegt."])
print("Embedding-Modell gecacht")
PY

# Whisper-Modell vorziehen. Ohne das lädt am Morgen von Kammer 6 jedes Team
# gleichzeitig 500 MB, und das Netz im Raum ist tot.
sudo apt-get install -y ffmpeg
python - <<'PY' || warn "Whisper-Modell konnte nicht vorgeladen werden"
from faster_whisper import WhisperModel
# "small" ist der Punkt, an dem deutsche Standardsprache zuverlaessig sitzt.
# "base" waere schneller, macht aber bei Fachbegriffen zu viele Fehler.
WhisperModel("small", device="cpu", compute_type="int8")
print("Whisper-Modell gecacht")
PY

# -----------------------------------------------------------------------------
log "8/12  Konfiguration OpenRouter-Anbindung (ohne Schlüssel)"
# -----------------------------------------------------------------------------
mkdir -p "$HOME_DIR/.config/bootcamp" "$HOME_DIR/.config/opencode" "$HOME_DIR/.continue"
[[ -f "$HOME_DIR/models.env" ]] && cp "$HOME_DIR/models.env" "$HOME_DIR/.config/bootcamp/models.env"

# Platzhalter-Env. bootcamp-setup füllt den Schlüssel ein.
if [[ ! -f "$HOME_DIR/.config/bootcamp/env" ]]; then
    cat >"$HOME_DIR/.config/bootcamp/env" <<'EOF'
# Persoenlicher OpenRouter-Zugang. Wird von bootcamp-setup befuellt.
# NICHT weitergeben, nicht in Git committen.
OPENROUTER_API_KEY=
OPENROUTER_BASE_URL=https://openrouter.ai/api/v1
# Die Python-Uebungen nutzen das OpenAI-SDK gegen OpenRouter:
OPENAI_API_KEY=
OPENAI_BASE_URL=https://openrouter.ai/api/v1
EOF
fi
chmod 600 "$HOME_DIR/.config/bootcamp/env"

# OpenCode auf OpenRouter richten
cat >"$HOME_DIR/.config/opencode/opencode.json" <<'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "model": "openrouter/anthropic/claude-sonnet-5",
  "provider": {
    "openrouter": {
      "options": { "apiKey": "{env:OPENROUTER_API_KEY}" }
    }
  }
}
EOF

# Continue auf OpenRouter richten (config.yaml = aktuelles Format)
cat >"$HOME_DIR/.continue/config.yaml" <<'EOF'
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

# Env in beide Shells laden
for rc in "$HOME_DIR/.bashrc" "$HOME_DIR/.profile"; do
    grep -q 'config/bootcamp/env' "$rc" 2>/dev/null || cat >>"$rc" <<'EOF'

# --- KI-Bootcamp ---
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$HOME/.opencode/bin:$PATH"
set -a; [ -f "$HOME/.config/bootcamp/env" ] && . "$HOME/.config/bootcamp/env"; set +a
alias bc='cd ~/bootcamp && source .venv/bin/activate'
alias webui='cd ~/bootcamp/docker && docker compose up -d && xdg-open http://localhost:3000'
EOF
done
ok "OpenCode und Continue konfiguriert (Schlüssel folgt beim ersten Start)"

# -----------------------------------------------------------------------------
log "9/12  Open WebUI vorbereiten"
# -----------------------------------------------------------------------------
cp "$HOME_DIR/docker-compose.yml" "$WORK/docker/docker-compose.yml"
docker pull ghcr.io/open-webui/open-webui:main
ok "Open-WebUI-Image im Bild vorgezogen (~1.5 GB, spart Bandbreite am Bootcamp)"

# -----------------------------------------------------------------------------
log "10/12  Ollama (optional, Profil 'standard')"
# -----------------------------------------------------------------------------
if [[ "$PROFIL" == "standard" ]]; then
    command -v ollama >/dev/null 2>&1 || curl -fsSL https://ollama.com/install.sh | sh
    sudo systemctl enable --now ollama || true
    sleep 5
    # Bewusst klein: auf 4 CPU-Kernen ohne GPU ist alles darueber Geduldsprobe.
    ollama pull qwen3:1.7b || warn "Modell-Pull fehlgeschlagen — später nachholen"
    ok "Ollama mit Kleinmodell — als Kontrast zu den Frontier-Modellen gedacht"
else
    warn "Profil 'sparsam': Ollama übersprungen"
fi

# -----------------------------------------------------------------------------
log "11/12  Ersteinrichtung und Hilfsskripte"
# -----------------------------------------------------------------------------
sudo install -m 755 "$HOME_DIR/bootcamp-setup" /usr/local/bin/bootcamp-setup

# Autostart der Ersteinrichtung, solange kein Schlüssel gesetzt ist
mkdir -p "$HOME_DIR/.config/autostart"
cat >"$HOME_DIR/.config/autostart/bootcamp-setup.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=KI-Bootcamp Ersteinrichtung
Exec=xfce4-terminal --title="KI-Bootcamp Ersteinrichtung" -e "bootcamp-setup"
Terminal=false
X-GNOME-Autostart-enabled=true
EOF

cat >"$WORK/scripts/selftest.sh" <<'EOF'
#!/usr/bin/env bash
# Abnahmetest der Bootcamp-VM
pass=0; fail=0
chk() { if eval "$2" >/dev/null 2>&1; then echo "  ✓ $1"; ((pass++)); else echo "  ✗ $1"; ((fail++)); fi; }

echo "── Werkzeuge ──"
chk "Python 3.12"       "python3 --version | grep -q 3.12"
chk "uv"                "command -v uv"
chk "Node 22+"          "node -v | grep -qE 'v(2[2-9]|[3-9][0-9])'"
chk "Git"               "command -v git"
chk "Docker laeuft"     "docker info"
chk "VS Code"           "command -v code"
chk "OpenCode"          "command -v opencode"

echo "── Python-Umgebung ──"
source ~/bootcamp/.venv/bin/activate 2>/dev/null
for m in openai httpx pydantic chromadb streamlit gradio fastapi pandas langchain langgraph pydantic_ai mcp; do
  chk "import $m" "python -c 'import $m'"
done

echo "── Zugang ──"
set -a; [ -f ~/.config/bootcamp/env ] && . ~/.config/bootcamp/env; set +a
chk "OPENROUTER_API_KEY gesetzt" '[ -n "$OPENROUTER_API_KEY" ]'
if [ -n "${OPENROUTER_API_KEY:-}" ]; then
  chk "OpenRouter erreichbar" \
    "curl -sf -H 'Authorization: Bearer $OPENROUTER_API_KEY' https://openrouter.ai/api/v1/key"
fi

echo
echo "  $pass bestanden, $fail offen"
[ "$fail" -eq 0 ] && echo "  VM ist bereit." || echo "  Bitte offene Punkte pruefen."
EOF
chmod +x "$WORK/scripts/selftest.sh"

# Proxy-Helfer für das BIT-Netz
cat >"$WORK/scripts/proxy-setup.sh" <<'EOF'
#!/usr/bin/env bash
# Proxy fuer apt, pip, npm und Docker setzen.  Aufruf: ./proxy-setup.sh http://proxy.bit.admin.ch:8080
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

cp "$HOME_DIR/prepare-export.sh" "$HOME_DIR/prepare-export.sh" 2>/dev/null || true
ok "Hilfsskripte unter $WORK/scripts/"

# -----------------------------------------------------------------------------
log "12/12  Übungsgerüst und Desktop"
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
print(f"Prompt: {antwort.usage.prompt_tokens} Tokens")
print(f"Antwort: {antwort.usage.completion_tokens} Tokens")
print("Aufgabe: Wechsle das Modell und vergleiche Qualitaet, Tempo und Tokenzahl.")
EOF

cat >"$WORK/uebungen/README.md" <<'EOF'
# Übungen

| Datei | Thema |
|---|---|
| `01_erster_api_call.py` | Erster Aufruf gegen OpenRouter, Tokens und Kosten sichtbar machen |

Die übrigen Übungen kommen vom Bootcamp-Anbieter und werden hier abgelegt.

Umgebung aktivieren: `bc`
Open WebUI starten: `webui`
Selbsttest: `~/bootcamp/scripts/selftest.sh`
EOF

xdg-mime default code.desktop text/plain 2>/dev/null || true

echo
echo "════════════════════════════════════════════════════════════"
echo "  Provisionierung abgeschlossen."
echo
echo "  1) Abmelden und neu anmelden (Docker-Gruppe)"
echo "  2) ~/bootcamp/scripts/selftest.sh"
echo "  3) Vor dem Export: ./prepare-export.sh"
echo "════════════════════════════════════════════════════════════"
