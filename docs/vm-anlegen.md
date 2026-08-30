# VM anlegen

Die VM wird von Hand angelegt und Debian von Hand installiert. Danach übernimmt `setup.sh`
alles Weitere über SSH.

Das ist bewusst so. Skripte für jede Hypervisor-Kombination zu pflegen kostet mehr, als der
Assistent spart, den ohnehin jeder kennt.

---

## Hypervisor

**VMware Workstation Pro (Windows, Linux) oder VMware Fusion Pro (macOS).** Beide sind seit
November 2024 kostenlos, auch kommerziell, und brauchen keinen Lizenzschlüssel.

Der Grund ist nicht Geschwindigkeit, sondern dass VMware neben aktiver
virtualisierungsbasierter Sicherheit läuft. VirtualBox tut das nicht: Oracle führt den
gemeinsamen Betrieb mit Hyper-V ausdrücklich als **experimentelle Funktion** und warnt in
den bekannten Einschränkungen vor schlechter Leistung. Zur Abhilfe müssten Hyper-V Platform,
Virtual Machine Platform und Windows Hypervisor Platform abgeschaltet werden — und selbst
das genügt nicht, denn auf neueren Windows-Versionen aktiviert bereits die Kernisolierung
oder Speicherintegrität Hyper-V wieder. Oracle verweist dann auf das Device-Guard-Werkzeug
von Microsoft und weist selbst darauf hin, dass dessen Einsatz die Sicherheit des Hosts
beeinträchtigt und mit der Administration abzusprechen ist.

Bei dreissig Geräten, davon ein Teil verwaltete BIT-Laptops, ist das kein Handgriff, sondern
ein Vorhaben mit Genehmigungsprozess.

**VirtualBox** funktioniert trotzdem und ist quelloffen. Wenn eine Vorgabe proprietäre
Software ausschliesst oder VBS auf euren Geräten ohnehin nicht erzwungen wird, ist es der
richtige Weg. Zwei Dinge dabei beachten:

- Das **Extension Pack nicht installieren.** Seine Lizenz erlaubt nur private und
  akademische Nutzung und schliesst Nutzung zugunsten staatlicher Organisationen
  ausdrücklich aus. Gebraucht wird es hier nicht.
- Bei NAT braucht es eine **Portweiterleitung** für SSH: Host `127.0.0.1:2222` auf Gast `22`,
  dann `./setup.sh -p 2222 bootcamp@127.0.0.1`.

**Apple Silicon.** Fusion mit einem ARM-Abbild von Debian, sonst identischer Ablauf. Kein
zweites vorgefertigtes Abbild nötig: Die wenigen Betroffenen legen ihre VM selbst an und
lassen `setup.sh` einmal laufen, das Skript ist architekturbewusst. VirtualBox auf Apple
Silicon scheidet aus — laut Handbuch laufen dort keine x86-Gäste, und ARM-Hosts haben
Einschränkungen bei Ton, Speicher, Grafik und Gasterweiterungen. Der Ton wird für die
Abschlussarbeit gebraucht.

---

## Einstellungen

Gleich für alle Hypervisoren.

| | Wert |
|---|---|
| Abbild | `debian-13.x.0-amd64-netinst.iso` (Apple Silicon: `arm64`) |
| Arbeitsspeicher | 6144 MB (Host mit 8 GB: 4096) |
| Prozessoren | 4 (Host mit 8 GB: 2) |
| Festplatte | 60 GB, wachsend, **nicht** in mehrere Dateien aufteilen |
| Grafikspeicher | 128 MB |
| 3D-Beschleunigung | aus |
| Verschachtelte Virtualisierung | aus |
| Netzwerk | NAT |
| Ton | Ausgabe an, Mikrofon aus |
| Zwischenablage | bidirektional |
| Gemeinsame Ordner | aus |

**Ton nicht vergessen.** In der Abschlussarbeit müssen die Lernenden eine Tonaufnahme
anhören. Eine stumme VM an diesem Morgen ist ein vermeidbares Ärgernis.

**Verschachtelte Virtualisierung aus.** Docker im Gast braucht sie nicht, und eingeschaltet
verhindert sie auf Hosts mit aktiver virtualisierungsbasierter Sicherheit den Start.

**Anforderungen an den Host:** x86-64 oder Apple Silicon, 8 GB Arbeitsspeicher (16 GB
empfohlen), **60 GB freier Speicherplatz**, lokale Administratorrechte. Der Speicherplatz
reisst bei privaten Geräten am häufigsten: Das Abbild ist rund 12 GB und wächst im Betrieb
auf 30 bis 40 GB.

---

## Debian installieren

Grafische Installation, Standardpfad. Diese Angaben:

```
Sprache            English
Standort           Switzerland
Tastatur           Swiss German
Rechnername        bit-ki-bootcamp
Domain             (leer)
Root-Passwort      LEER LASSEN            ← wichtig, siehe unten
Benutzer           bootcamp
Passwort           bootcamp
Partitionierung    Geführt, gesamte Festplatte, alles in eine Partition
```

Bei der Softwareauswahl am Schluss:

```
[*] Debian desktop environment
[*] Xfce
[*] SSH server
[*] Standard-Systemwerkzeuge
[ ] GNOME, KDE und alle übrigen abwählen
```

**Das Root-Passwort leer lassen ist keine Nachlässigkeit.** Debian vergibt sudo-Rechte an den
ersten Benutzer nur dann, wenn kein Root-Passwort gesetzt wurde. Andernfalls landet
`bootcamp` nicht in der Gruppe `sudo`, und die Provisionierung bricht sofort ab. Das ist der
häufigste Stolperstein beim ersten Aufbau.

Falls es doch passiert ist, in der VM als root nachholen:

```bash
su -
apt install -y sudo && /sbin/usermod -aG sudo bootcamp
```

Danach ab- und wieder anmelden.

**Warum XFCE und nicht GNOME:** rund 800 MB weniger Arbeitsspeicher, und es läuft auf X11.
Damit funktionieren Zwischenablage und automatische Auflösungsanpassung unter jedem
Hypervisor gleich, statt unter Wayland je nach Hypervisor anders.

---

## Adresse ermitteln und provisionieren

Nach dem ersten Start in der VM ein Terminal öffnen:

```bash
hostname -I
```

Dann auf dem Host, im Ordner mit diesem Repository:

```bash
./setup.sh 192.168.1.42          # macOS, Linux
.\setup.ps1 192.168.1.42         # Windows
```

Bei VMware erreicht der Host die Adresse im NAT-Betrieb direkt. Bei VirtualBox braucht es die
oben beschriebene Portweiterleitung.

Dauer 40 bis 60 Minuten. Danach in der VM ab- und wieder anmelden, dann:

```bash
~/bootcamp/scripts/selftest.sh
```

---

## Verteilen

Nur nötig, wenn ein Abbild für alle gebaut wird statt jede VM einzeln zu provisionieren.

```bash
~/bootcamp/scripts/prepare-export.sh
sudo poweroff
```

Danach auf dem Host kompaktieren, exportieren und eine Prüfsumme bilden. Erwartete Grösse
9 bis 13 GB. Die genauen Befehle gibt das Skript am Ende aus.

Die Prüfsumme ist kein Formalismus: Ein abgebrochener Download fällt sonst erst nach zwanzig
Minuten Import auf.
