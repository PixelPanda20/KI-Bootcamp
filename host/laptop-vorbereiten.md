# Laptop-Konfiguration (Host)

Gilt für BIT-Geräte mit Admin-Rechten und für private Laptops gleichermassen.

---

## Anforderungen

| | Minimum | Empfohlen |
|---|---|---|
| Prozessor | x86-64 mit VT-x/AMD-V | 4 Kerne oder mehr |
| Arbeitsspeicher | 8 GB | 16 GB |
| Freier Speicherplatz | **60 GB** | 80 GB |
| Rechte | lokaler Administrator | |
| VirtualBox | 7.0 | 7.2 oder neuer |

**Apple Silicon geht nicht.** VirtualBox führt auf MacBooks mit M1 bis M4 keine x86-Systeme
aus. Betroffene brauchen ein Leihgerät oder ein separates ARM-Abbild für UTM.

**Speicherplatz** ist der Punkt, der am häufigsten reisst. Das OVA ist rund 12 GB, die
entpackte VM wächst im Betrieb auf 30 bis 40 GB. Wer 60 GB nicht frei hat, merkt das sonst
mitten im Import.

---

## Extension Pack: nicht installieren

Das VirtualBox Extension Pack steht unter einer eigenen Lizenz von Oracle und ist nicht
quelloffen. Für den gewerblichen Einsatz braucht es eine kostenpflichtige Lizenz, und eine
flächendeckende Installation in einer Bundesverwaltung wäre lizenzrechtlich heikel.

Gebraucht wird es hier ohnehin nicht. Es liefert USB-2.0- und USB-3.0-Durchreichung, RDP und
Festplattenverschlüsselung. Nichts davon braucht diese VM. Alles Nötige steckt im quelloffenen
Basispaket.

---

## Windows

**Hyper-V prüfen.** `Win + R`, `msinfo32`. Steht unter *Virtualisierungsbasierte Sicherheit*
etwas von *Wird ausgeführt*, läuft VirtualBox nur im langsamen Ersatzmodus.

Abschalten, in einer Eingabeaufforderung als Administrator:

```
bcdedit /set hypervisorlaunchtype off
```

Zusätzlich unter *Windows-Features aktivieren oder deaktivieren* abwählen:

- Hyper-V
- Windows-Hypervisor-Plattform
- Plattform für virtuelle Computer
- Windows-Sandbox

Danach neu starten und mit `msinfo32` prüfen, ob es geblieben ist.

**Zwei Nebenwirkungen.** WSL funktioniert danach nicht mehr. Und wenn die Einstellung nach dem
Neustart wieder aktiv ist, greift eine Gruppenrichtlinie; dann hilft nur der Weg über die
Client-Verantwortlichen. Genau deshalb muss dieser Test einmal auf einem produktiven BIT-Image
laufen, bevor dreissig Lernende es einzeln versuchen.

Rückweg: `bcdedit /set hypervisorlaunchtype auto` plus Neustart.

**Virenscanner.** Den VM-Ordner von der Echtzeitprüfung ausnehmen. Ein Scanner, der eine
40-GB-Datei bei jedem Schreibzugriff prüft, halbiert die Geschwindigkeit der VM.

---

## macOS (Intel)

VirtualBox von virtualbox.org installieren. Beim ersten Start blockiert macOS die
Kernelerweiterung.

*Systemeinstellungen → Datenschutz & Sicherheit*, ganz unten auf **Erlauben** klicken, dann
neu starten. Ohne diesen Schritt startet keine VM, und die Fehlermeldung sagt nicht, woran es
liegt.

Bei Apple Silicon nicht weiterprobieren. Siehe oben.

---

## Linux

```bash
sudo apt install virtualbox virtualbox-dkms virtualbox-qt   # Debian/Ubuntu
sudo usermod -aG vboxusers "$USER"                          # danach neu anmelden
```

**Secure Boot.** Ist es aktiv, lädt der Kernel die VirtualBox-Module nicht. Beim Installieren
fragt DKMS nach einem Passwort für die Schlüsselregistrierung; beim nächsten Start erscheint
das blaue MOK-Menü, dort *Enroll MOK* wählen und dasselbe Passwort eingeben. Wer den Moment
verpasst, muss die Registrierung wiederholen.

Alternativ Secure Boot im BIOS abschalten, wenn das Gerät das zulässt.

---

## Einstellungen der VM

Werden vom Erstellungsskript gesetzt. Nach dem Import einer OVA sind sie bereits enthalten
und müssen nur bei Bedarf angepasst werden.

| Einstellung | Wert | Warum |
|---|---|---|
| Arbeitsspeicher | 6144 MB | Standardprofil bei 16 GB Host |
| Prozessoren | 4 | |
| Grafikspeicher | 128 MB | reicht für 1920x1080 |
| Grafikcontroller | VMSVGA | |
| 3D-Beschleunigung | aus | unter Linux-Gästen unzuverlässig, bringt für XFCE nichts |
| Paravirtualisierung | KVM | für Linux-Gäste spürbar schneller als *Standard* |
| Verschachtelte Virtualisierung | aus | Docker im Gast braucht sie nicht, eingeschaltet verhindert sie auf manchen Hosts den Start |
| Netzwerk | NAT, Intel PRO/1000 MT | virtio wäre schneller, der Intel-Adapter wird überall ohne Nachfrage erkannt |
| Ton | Ausgabe an, Eingabe aus | für die Tonaufnahmen in der Abschlussarbeit |
| Zwischenablage | bidirektional | |
| Drag & Drop | bidirektional | |
| Platte | 60 GB VDI, dynamisch | |

### Portweiterleitungen

Damit die Dienste im Gast auch vom Host-Browser erreichbar sind. Zwingend ist das nicht, die
Lernenden arbeiten im Gast.

| Dienst | Host | Gast |
|---|---|---|
| Open WebUI | 127.0.0.1:3000 | 3000 |
| n8n | 127.0.0.1:5678 | 5678 |
| Streamlit | 127.0.0.1:8501 | 8501 |
| eigene API | 127.0.0.1:8000 | 8000 |

Bindung an 127.0.0.1 statt an alle Adressen. Sonst ist Open WebUI im Gäste-WLAN für alle im
Raum offen.

### Sparprofil für Hosts mit 8 GB

```bash
VBoxManage modifyvm bit-ki-bootcamp --memory 4096 --cpus 2
```

Dazu im Gast Ollama abschalten, sonst wird es eng:

```bash
sudo systemctl disable --now ollama
```

---

## Nach dem Import, für die Lernenden

1. VM einmal starten und wieder herunterfahren.
2. **Snapshot anlegen.** `Machine → Take Snapshot`, Name *Startzustand*. Damit lässt sich
   jederzeit zurück, wenn etwas kaputtgeht. Das wird vorkommen, und dafür ist eine VM da.
3. Anmelden mit `bootcamp` / `bootcamp`.
4. Die Ersteinrichtung startet von selbst und fragt den persönlichen API-Schlüssel ab.
5. `~/bootcamp/scripts/selftest.sh` ausführen. Alles grün heisst startklar.
