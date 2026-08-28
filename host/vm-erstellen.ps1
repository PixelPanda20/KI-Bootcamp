# =============================================================================
#  KI-Bootcamp — VM auf dem Host erzeugen (Windows)
#
#  Inhaltlich identisch zu vm-erstellen.sh. Aufruf in PowerShell:
#      .\vm-erstellen.ps1 -Iso "C:\Downloads\xubuntu-24.04.3-desktop-amd64.iso"
# =============================================================================
param(
    [Parameter(Mandatory = $true)][string]$Iso,
    [string]$Name   = "bit-ki-bootcamp",
    [int]$RamMb     = 6144,
    [int]$Cpus      = 4,
    [int]$DiskMb    = 61440
)

$ErrorActionPreference = "Stop"
$vbox = "$env:ProgramFiles\Oracle\VirtualBox\VBoxManage.exe"

if (-not (Test-Path $vbox)) { throw "VBoxManage nicht gefunden: $vbox" }
if (-not (Test-Path $Iso))  { throw "ISO nicht gefunden: $Iso" }

$vmDir = (& $vbox list systemproperties |
          Select-String "Default machine folder" |
          ForEach-Object { ($_ -split ":\s+", 2)[1].Trim() })
$disk = Join-Path $vmDir "$Name\$Name.vdi"

Write-Host "> VM anlegen"
& $vbox createvm --name $Name --ostype Ubuntu_64 --register

Write-Host "> Grundeinstellungen"
& $vbox modifyvm $Name `
    --memory $RamMb --cpus $Cpus --vram 128 `
    --graphicscontroller vmsvga --accelerate3d off `
    --rtcuseutc on --paravirtprovider kvm `
    --nested-hw-virt off --ioapic on --pae off

Write-Host "> Netz"
& $vbox modifyvm $Name --nic1 nat --nictype1 82540EM --cableconnected1 on
& $vbox modifyvm $Name --natpf1 "openwebui,tcp,127.0.0.1,3000,,3000"
& $vbox modifyvm $Name --natpf1 "n8n,tcp,127.0.0.1,5678,,5678"
& $vbox modifyvm $Name --natpf1 "streamlit,tcp,127.0.0.1,8501,,8501"
& $vbox modifyvm $Name --natpf1 "api,tcp,127.0.0.1,8000,,8000"

Write-Host "> Ton (nur Ausgabe)"
& $vbox modifyvm $Name --audio-driver default --audio-enabled on --audio-out on --audio-in off

Write-Host "> Zwischenablage"
& $vbox modifyvm $Name --clipboard-mode bidirectional --draganddrop bidirectional

Write-Host "> Platte"
& $vbox createmedium disk --filename $disk --size $DiskMb --variant Standard
& $vbox storagectl $Name --name SATA --add sata --controller IntelAhci --portcount 2 --hostiocache on
& $vbox storageattach $Name --storagectl SATA --port 0 --device 0 --type hdd --medium $disk

Write-Host "> Installationsmedium"
& $vbox storagectl $Name --name IDE --add ide
& $vbox storageattach $Name --storagectl IDE --port 0 --device 0 --type dvddrive --medium $Iso
& $vbox modifyvm $Name --boot1 dvd --boot2 disk --boot3 none --boot4 none

Write-Host ""
Write-Host "VM '$Name' erstellt: $RamMb MB RAM, $Cpus CPU, $([math]::Round($DiskMb/1024)) GB"
Write-Host "Weiter: VM starten, Xubuntu installieren (bootcamp/bootcamp),"
Write-Host "Guest Additions, dann gast\provision.sh im Gast ausfuehren."
