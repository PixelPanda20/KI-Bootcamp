#!/usr/bin/env bash
# =============================================================================
#  KI-Bootcamp — VM provisionieren
#
#      ./setup.sh 192.168.1.42                  Benutzer bootcamp wird angenommen
#      ./setup.sh bootcamp@192.168.1.42
#      ./setup.sh -p 2222 bootcamp@127.0.0.1    VirtualBox mit Portweiterleitung
#      PROFIL=sparsam ./setup.sh 192.168.1.42   Host mit 8 GB, ohne Ollama
#
#  Voraussetzung: In der VM läuft Debian 13 mit XFCE und aktivem SSH-Server.
#  Die Adresse liefert in der VM:  hostname -I
#
#  Dauer 40 bis 60 Minuten. Das sudo-Passwort wird einmal abgefragt.
# =============================================================================
set -Eeuo pipefail

PORT=22
while getopts "p:" opt; do
    case "$opt" in
        p) PORT="$OPTARG" ;;
        *) echo "Aufruf: $0 [-p port] [benutzer@]adresse"; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

ZIEL="${1:?Aufruf: ./setup.sh [-p port] [benutzer@]adresse}"
[[ "$ZIEL" == *@* ]] || ZIEL="bootcamp@$ZIEL"

HIER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -d "$HIER/gast" ]] || { echo "Ordner gast/ nicht gefunden neben $0"; exit 1; }

# Eine einzige Verbindung für alles. Ohne ControlMaster fragt SSH bei jedem
# Schritt erneut nach dem Passwort, und das wären hier drei Mal.
SOCK="$(mktemp -u /tmp/ki-bootcamp-%C.sock)"
SSH=(ssh -p "$PORT" -o ControlMaster=auto -o ControlPath="$SOCK" -o ControlPersist=15m
     -o StrictHostKeyChecking=accept-new)

aufräumen() { "${SSH[@]}" -O exit "$ZIEL" 2>/dev/null || true; }
trap aufräumen EXIT

echo "▶ Verbindung zu $ZIEL prüfen"
"${SSH[@]}" "$ZIEL" 'echo "  $(hostname) — $(cat /etc/debian_version 2>/dev/null || uname -sr)"'

echo "▶ Konfiguration übertragen"
tar czf - -C "$HIER" gast | "${SSH[@]}" "$ZIEL" \
    'rm -rf ~/gast && tar xzf - && echo "  übertragen"'

echo "▶ Provisionierung starten"
echo
"${SSH[@]}" -t "$ZIEL" \
    "cd ~/gast && chmod +x provision.sh && PROFIL='${PROFIL:-standard}' ./provision.sh 2>&1 | tee ~/provision.log"

cat <<EOF

════════════════════════════════════════════════════════════
  Fertig. In der VM einmal ab- und wieder anmelden, dann:
      ~/bootcamp/scripts/selftest.sh

  Protokoll in der VM unter ~/provision.log
════════════════════════════════════════════════════════════
EOF
