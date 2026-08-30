# =============================================================================
#  KI-Bootcamp — VM provisionieren (Windows)
#
#      .\setup.ps1 192.168.1.42
#      .\setup.ps1 bootcamp@192.168.1.42
#      .\setup.ps1 -Ziel 127.0.0.1 -Port 2222        VirtualBox mit Weiterleitung
#      .\setup.ps1 192.168.1.42 -Profil sparsam      Host mit 8 GB
#
#  Der OpenSSH-Client und tar sind in Windows 10 und 11 enthalten.
#  Kein PuTTY, kein WSL nötig.
# =============================================================================
param(
    [Parameter(Mandatory = $true, Position = 0)][string]$Ziel,
    [int]$Port = 22,
    [ValidateSet("standard", "sparsam")][string]$Profil = "standard"
)

$ErrorActionPreference = "Stop"
if ($Ziel -notmatch "@") { $Ziel = "bootcamp@$Ziel" }

$hier = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not (Test-Path (Join-Path $hier "gast"))) {
    throw "Ordner gast\ nicht gefunden neben diesem Skript"
}

$opts = @("-p", "$Port", "-o", "StrictHostKeyChecking=accept-new")

Write-Host "> Verbindung zu $Ziel pruefen"
& ssh @opts $Ziel 'echo "  $(hostname) — $(cat /etc/debian_version 2>/dev/null || uname -sr)"'
if ($LASTEXITCODE -ne 0) { throw "Keine Verbindung. Laeuft der SSH-Server in der VM?" }

Write-Host "> Konfiguration uebertragen"
& scp @opts -r (Join-Path $hier "gast") "${Ziel}:~/"
if ($LASTEXITCODE -ne 0) { throw "Uebertragung fehlgeschlagen" }

Write-Host "> Provisionierung starten"
Write-Host ""
& ssh @opts -t $Ziel "cd ~/gast && chmod +x provision.sh && PROFIL='$Profil' ./provision.sh 2>&1 | tee ~/provision.log"

Write-Host ""
Write-Host "============================================================"
Write-Host "  Fertig. In der VM einmal ab- und wieder anmelden, dann:"
Write-Host "      ~/bootcamp/scripts/selftest.sh"
Write-Host "============================================================"
