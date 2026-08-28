#!/usr/bin/env bash
# =============================================================================
#  VM für den OVA-Export vorbereiten
#
#  Räumt Caches und Spuren des Aufbaus weg und nullt den freien Speicher,
#  damit sich das VDI danach kompaktieren lässt. Ohne diesen Schritt ist das
#  OVA gut und gerne doppelt so gross.
#
#  Nach dem Lauf: VM herunterfahren, dann auf dem Host
#      VBoxManage modifymedium disk <pfad>.vdi --compact
# =============================================================================
set -Eeuo pipefail

echo "▶ Dienste stoppen"
cd ~/bootcamp/docker && docker compose down 2>/dev/null || true

echo "▶ Persönliche Spuren entfernen"
: >~/.config/bootcamp/env.tmp
cat >~/.config/bootcamp/env <<'EOF'
OPENROUTER_API_KEY=
OPENROUTER_BASE_URL=https://openrouter.ai/api/v1
OPENAI_API_KEY=
OPENAI_BASE_URL=https://openrouter.ai/api/v1
EOF
rm -f ~/.config/bootcamp/env.tmp
chmod 600 ~/.config/bootcamp/env

# Ersteinrichtung beim ersten Start der Lernenden wieder aktivieren
mkdir -p ~/.config/autostart
cat >~/.config/autostart/bootcamp-setup.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=KI-Bootcamp Ersteinrichtung
Exec=xfce4-terminal --title="KI-Bootcamp Ersteinrichtung" -e "bootcamp-setup"
Terminal=false
X-GNOME-Autostart-enabled=true
EOF

rm -f ~/.bash_history ~/.python_history ~/provision.log
rm -rf ~/.ssh ~/.gitconfig ~/.config/gh ~/.local/share/opencode/auth* 2>/dev/null || true
git config --global --unset-all user.email 2>/dev/null || true
git config --global --unset-all user.name 2>/dev/null || true

echo "▶ Caches leeren"
sudo apt-get -y autoremove --purge
sudo apt-get -y clean
sudo rm -rf /var/lib/apt/lists/*
rm -rf ~/.cache/pip ~/.cache/uv ~/.npm/_cacache ~/.cache/thumbnails
docker builder prune -af 2>/dev/null || true
docker image prune -f 2>/dev/null || true
sudo journalctl --rotate && sudo journalctl --vacuum-time=1s
sudo rm -rf /var/log/*.gz /var/log/*.1 /tmp/* /var/tmp/*

echo "▶ Maschinenspezifisches zurücksetzen"
# Sonst bekommen alle importierten Kopien dieselbe machine-id und
# DHCP vergibt ihnen im selben Netz dieselbe Adresse.
sudo truncate -s 0 /etc/machine-id
sudo rm -f /var/lib/dbus/machine-id
sudo ln -sf /etc/machine-id /var/lib/dbus/machine-id
sudo rm -f /etc/ssh/ssh_host_*

echo "▶ Freien Speicher nullen (dauert einige Minuten)"
sudo dd if=/dev/zero of=/EMPTY bs=1M status=progress 2>/dev/null || true
sudo rm -f /EMPTY
sync

echo
echo "════════════════════════════════════════════════════════════"
echo "  Bereit für den Export. Jetzt: sudo poweroff"
echo
echo "  Auf dem Host:"
echo "    VBoxManage modifymedium disk <pfad>.vdi --compact"
echo "    VBoxManage export bit-ki-bootcamp -o BIT-KI-Bootcamp-2026-v1.ova \\"
echo "        --vsys 0 --product \"BIT KI-Bootcamp 2026\" --vendor \"BIT\""
echo "    sha256sum BIT-KI-Bootcamp-2026-v1.ova > BIT-KI-Bootcamp-2026-v1.sha256"
echo "════════════════════════════════════════════════════════════"
