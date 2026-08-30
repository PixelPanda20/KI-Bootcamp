#!/usr/bin/env bash
# =============================================================================
#  Podman Desktop — native Desktop-Anwendung zur Container-Verwaltung
#
#      ~/bootcamp/scripts/podman-desktop.sh
#
#  BEWUSST NICHT TEIL DER STANDARD-PROVISIONIERUNG.
#
#  Podman Desktop ist eine Electron-Anwendung und belegt im Betrieb 400 bis
#  500 MB. In einer VM mit 6 GB, in der XFCE, VS Code, Firefox und Open WebUI
#  liegen, ist das viel für eine Oberfläche. Portainer kostet 100 MB, die
#  Docker-Erweiterung in VS Code gar nichts.
#
#  Wer die native Anwendung trotzdem will, ist hier richtig. Auf einer VM mit
#  8 GM oder mehr ist es unproblematisch.
#
#  Installiert wird das Archiv von GitHub, nicht das Flatpak: Ubuntu bringt
#  Flatpak nicht mit, und die GNOME-Laufzeitumgebung nachzuinstallieren kostet
#  rund 1 GB für eine einzige Anwendung.
# =============================================================================
set -Eeuo pipefail

ZIEL="$HOME/.local/opt/podman-desktop"
ARCH="$(dpkg --print-architecture)"
case "$ARCH" in
    amd64) MUSTER='linux-x64.tar.gz' ;;
    arm64) MUSTER='linux-arm64.tar.gz' ;;
    *)     echo "Architektur $ARCH wird nicht unterstützt."; exit 1 ;;
esac

echo "▶ Neueste Ausgabe ermitteln"
URL="$(curl -fsSL https://api.github.com/repos/podman-desktop/podman-desktop/releases/latest \
       | grep -o "https://[^\"]*${MUSTER}" | head -1)"
[[ -n "$URL" ]] || { echo "Kein passendes Archiv gefunden. Bitte manuell von podman-desktop.io laden."; exit 1; }
echo "  $URL"

echo "▶ Herunterladen und entpacken"
mkdir -p "$ZIEL"
curl -fL "$URL" | tar xz -C "$ZIEL" --strip-components=1

BIN="$(find "$ZIEL" -maxdepth 1 -type f -name 'podman-desktop*' -perm -u+x | head -1)"
[[ -n "$BIN" ]] || BIN="$ZIEL/podman-desktop"
chmod +x "$BIN"

echo "▶ Startmenü-Eintrag"
mkdir -p "$HOME/.local/share/applications" "$HOME/.local/bin"
ln -sf "$BIN" "$HOME/.local/bin/podman-desktop"
ICON="$(find "$ZIEL" -name '*.png' -path '*icon*' | head -1)"
cat >"$HOME/.local/share/applications/podman-desktop.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Podman Desktop
Comment=Container und Abbilder verwalten
Exec=$BIN --no-sandbox
Icon=${ICON:-utilities-terminal}
Terminal=false
Categories=Development;System;
EOF
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

# Podman Desktop erwartet den Container-Socket über DOCKER_HOST. Ohne diese
# Zeile findet es die laufende Docker-Engine je nach Ausgabe nicht von selbst.
grep -q 'DOCKER_HOST' "$HOME/.bashrc" 2>/dev/null || \
    echo 'export DOCKER_HOST=unix:///var/run/docker.sock' >> "$HOME/.bashrc"

cat <<'EOF'

════════════════════════════════════════════════════════════
  Podman Desktop installiert. Über das Startmenü aufrufbar.

  Beim ersten Start:
    Einstellungen → Docker Compatibility prüfen.
    Die laufende Docker-Engine erscheint dort als Ressource;
    Container und Abbilder werden dann in der Übersicht gezeigt.

  Falls nichts erscheint: Bist du in der Gruppe "docker"?
    groups | grep docker
  Falls nicht, einmal ab- und wieder anmelden.

  Deinstallieren:
    rm -rf ~/.local/opt/podman-desktop \
           ~/.local/share/applications/podman-desktop.desktop \
           ~/.local/bin/podman-desktop
════════════════════════════════════════════════════════════
EOF
