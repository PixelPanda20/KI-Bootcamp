#!/usr/bin/env bash
# =============================================================================
#  VM für die Verteilung vorbereiten
#
#  Räumt Caches, persönliche Spuren und maschinenspezifische Kennungen weg und
#  nullt den freien Speicher, damit sich das Abbild kompaktieren lässt. Ohne
#  diesen Schritt ist das Ergebnis gut und gerne doppelt so gross.
#
#  Danach: sudo poweroff, dann auf dem Host kompaktieren und exportieren.
# =============================================================================
set -Eeuo pipefail

echo "▶ Dienste stoppen"
cd ~/bootcamp/docker 2>/dev/null && \
    docker compose --profile tools --profile rag --profile lcnc down 2>/dev/null || true

# Portainer-Datenbank verwerfen, sonst reist der Anmeldezustand des Aufbauteams
# in dreissig Kopien mit. Die Passwortdatei bleibt, damit der erste Start beim
# Lernenden ohne Einrichtungsfrist durchläuft.
docker volume rm docker_portainer-data 2>/dev/null || true

echo "▶ Persönliche Spuren entfernen"
cat >~/.config/bootcamp/env <<'EOF'
OPENROUTER_API_KEY=
OPENROUTER_BASE_URL=https://openrouter.ai/api/v1
OPENAI_API_KEY=
OPENAI_BASE_URL=https://openrouter.ai/api/v1
EOF
chmod 600 ~/.config/bootcamp/env

# Ersteinrichtung beim ersten Start der Lernenden wieder aktivieren
mkdir -p ~/.config/autostart
cat >~/.config/autostart/bootcamp-setup.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=KI-Bootcamp Ersteinrichtung
Exec=sh -c 'sleep 5; x-terminal-emulator -e bootcamp-setup'
Terminal=false
X-GNOME-Autostart-enabled=true
EOF

rm -f ~/.bash_history ~/.python_history ~/provision.log
rm -rf ~/gast                                    # vom Host übertragene Konfiguration
rm -rf ~/.ssh ~/.gitconfig ~/.config/gh ~/.local/share/opencode/auth* 2>/dev/null || true
git config --global --unset-all user.email 2>/dev/null || true
git config --global --unset-all user.name  2>/dev/null || true

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
# Sonst bekommen alle importierten Kopien dieselbe machine-id, und im selben
# Netz vergibt DHCP ihnen dieselbe Adresse.
sudo truncate -s 0 /etc/machine-id
sudo rm -f /var/lib/dbus/machine-id
sudo ln -sf /etc/machine-id /var/lib/dbus/machine-id
sudo rm -f /etc/ssh/ssh_host_*

echo "▶ Freien Speicher nullen (dauert einige Minuten)"
sudo dd if=/dev/zero of=/EMPTY bs=1M status=progress 2>/dev/null || true
sudo rm -f /EMPTY
sync

cat <<'EOF'

════════════════════════════════════════════════════════════
  Bereit. Jetzt: sudo poweroff

  Auf dem Host kompaktieren und exportieren:

  VMware
    vmware-vdiskmanager -k <pfad>/bit-ki-bootcamp.vmdk
    ovftool <pfad>/bit-ki-bootcamp.vmx BIT-KI-Bootcamp-v1.ova

  VirtualBox
    VBoxManage modifymedium disk <pfad>.vdi --compact
    VBoxManage export bit-ki-bootcamp -o BIT-KI-Bootcamp-v1.ova

  Danach Prüfsumme bilden und mit ausliefern:
    sha256sum BIT-KI-Bootcamp-v1.ova > BIT-KI-Bootcamp-v1.sha256
════════════════════════════════════════════════════════════
EOF
