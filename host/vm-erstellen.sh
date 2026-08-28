#!/usr/bin/env bash
# =============================================================================
#  KI-Bootcamp — VM auf dem Host erzeugen
#
#  Für die Personen, die das Abbild BAUEN. Die Lernenden importieren später nur
#  noch das fertige OVA und führen dieses Skript nicht aus.
#
#      ./vm-erstellen.sh /pfad/zu/xubuntu-24.04.3-desktop-amd64.iso
#
#  Danach: VM starten, Xubuntu installieren, Guest Additions, dann im Gast
#  gast/provision.sh ausführen.
# =============================================================================
set -Eeuo pipefail

NAME="${VM_NAME:-bit-ki-bootcamp}"
RAM_MB="${RAM_MB:-6144}"          # Standardprofil, Host mit 16 GB
CPUS="${CPUS:-4}"
DISK_MB="${DISK_MB:-61440}"       # 60 GB, dynamisch
ISO="${1:?Pfad zur Xubuntu-ISO angeben}"

VMDIR="$(VBoxManage list systemproperties | awk -F: '/Default machine folder/{sub(/^ +/,"",$2); print $2}')"
DISK="$VMDIR/$NAME/$NAME.vdi"

command -v VBoxManage >/dev/null || { echo "VBoxManage nicht gefunden."; exit 1; }
[[ -f "$ISO" ]] || { echo "ISO nicht gefunden: $ISO"; exit 1; }
VBoxManage showvminfo "$NAME" >/dev/null 2>&1 && { echo "VM '$NAME' existiert bereits."; exit 1; }

echo "▶ VM anlegen"
VBoxManage createvm --name "$NAME" --ostype Ubuntu_64 --register

echo "▶ Grundeinstellungen"
VBoxManage modifyvm "$NAME" \
    --memory "$RAM_MB" \
    --cpus "$CPUS" \
    --vram 128 \
    --graphicscontroller vmsvga \
    --accelerate3d off \
    --rtcuseutc on \
    --paravirtprovider kvm \
    --nested-hw-virt off \
    --ioapic on \
    --pae off

# 3D bleibt aus. Die VirtualBox-3D-Beschleunigung ist unter Linux-Gästen
# unzuverlässig und bringt für XFCE nichts. 128 MB VRAM reichen für 1920x1080.
#
# paravirtprovider kvm ist für Linux-Gäste spürbar schneller als "default".
#
# nested-hw-virt aus: Docker im Gast braucht das nicht, und eingeschaltet
# verhindert es auf manchen Hosts den Start.

echo "▶ Netz"
# Bewusst der Intel-Standardadapter statt virtio. Virtio wäre schneller,
# aber der Intel-Adapter wird von jedem Host und jedem Gast ohne Nachfrage
# erkannt — bei 30 importierten Kopien zählt das mehr als Durchsatz.
VBoxManage modifyvm "$NAME" --nic1 nat --nictype1 82540EM --cableconnected1 on

# Portweiterleitungen, damit die Dienste im Gast auch vom Host-Browser
# erreichbar sind. Nötig ist das nicht, die Lernenden arbeiten im Gast.
VBoxManage modifyvm "$NAME" --natpf1 "openwebui,tcp,127.0.0.1,3000,,3000"
VBoxManage modifyvm "$NAME" --natpf1 "n8n,tcp,127.0.0.1,5678,,5678"
VBoxManage modifyvm "$NAME" --natpf1 "streamlit,tcp,127.0.0.1,8501,,8501"
VBoxManage modifyvm "$NAME" --natpf1 "api,tcp,127.0.0.1,8000,,8000"

echo "▶ Ton"
# Nur Ausgabe. Die Lernenden müssen in der Abschlussarbeit eine Tonaufnahme
# anhören. Mikrofon bleibt aus, das braucht niemand und es spart Fragen.
VBoxManage modifyvm "$NAME" --audio-driver default --audio-enabled on \
    --audio-out on --audio-in off 2>/dev/null || \
VBoxManage modifyvm "$NAME" --audio default --audioout on --audioin off

echo "▶ Zwischenablage und Drag & Drop"
VBoxManage modifyvm "$NAME" --clipboard-mode bidirectional --draganddrop bidirectional

echo "▶ Platte"
VBoxManage createmedium disk --filename "$DISK" --size "$DISK_MB" --variant Standard
VBoxManage storagectl "$NAME" --name SATA --add sata --controller IntelAhci --portcount 2 --hostiocache on
VBoxManage storageattach "$NAME" --storagectl SATA --port 0 --device 0 --type hdd --medium "$DISK"

echo "▶ Installationsmedium"
VBoxManage storagectl "$NAME" --name IDE --add ide
VBoxManage storageattach "$NAME" --storagectl IDE --port 0 --device 0 --type dvddrive --medium "$ISO"
VBoxManage modifyvm "$NAME" --boot1 dvd --boot2 disk --boot3 none --boot4 none

cat <<EOF

════════════════════════════════════════════════════════════════
  VM '$NAME' erstellt.
    $RAM_MB MB RAM · $CPUS CPU · $((DISK_MB/1024)) GB Platte

  Weiter:
    1) VBoxManage startvm "$NAME"
    2) Xubuntu installieren
         Benutzer:  bootcamp
         Passwort:  bootcamp
         Rechner:   bit-ki-bootcamp
         Tastatur:  Schweiz (de_CH)
         Sprache:   English
    3) Nach der Installation ISO auswerfen:
         VBoxManage storageattach "$NAME" --storagectl IDE --port 0 \\
           --device 0 --type dvddrive --medium emptydrive
    4) Guest Additions im Gast installieren
    5) gast/provision.sh im Gast ausführen
    6) gast/prepare-export.sh, dann OVA exportieren
════════════════════════════════════════════════════════════════
EOF
