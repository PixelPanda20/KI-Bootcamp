# Gerätecheck

Erhebung der Geräte, bevor das Abbild gebaut wird.

Diese Erhebung entscheidet drei Dinge: **wie viele Leihgeräte** beschafft werden müssen, **ob
ein ARM-Abbild** nötig ist, und **welche Geräte überhaupt taugen**. Alle drei haben
Vorlaufzeit, keines lässt sich in der Woche vor dem Kurs nachholen.

**Rückmeldefrist setzen und durchsetzen.** Wer sich bis zum Stichtag nicht meldet, wird
angerufen. Erfahrungsgemäss antworten genau die nicht, bei denen es später klemmt.

---

## Die wichtigste Änderung: 16 GB im Host

Die VM läuft mit GNOME und bekommt 8 GB zugeteilt. An der fertigen VM gemessen belegt GNOME
auf Wayland mit laufendem Open WebUI 1,9 GB — reichlich Luft, solange die 8 GB da sind.

Damit verschiebt sich die Anforderung an den Host. Ein Gerät mit 8 GB kann der VM realistisch
nicht mehr als 4 GB abgeben, weil das Wirtsystem selbst 3 bis 4 GB braucht. GNOME, Docker,
VS Code und ein Agenten-Verbund in 4 GB sind kein Vergnügen, auch mit komprimierter
Auslagerung nicht.

**Geräte mit 8 GB kommen deshalb neu in die Leihgeräte-Spur.** In der ersten Fassung galten
8 GB noch als Minimum. Das war die Rechnung für XFCE und eine 6-GB-VM.

Praktische Folge: Der Anteil an Leihgeräten fällt höher aus als ursprünglich geplant. Genau
deshalb muss diese Erhebung jetzt raus und nicht im Oktober.

---

## Die drei Gerätespuren

| Spur | Wer | Was |
|---|---|---|
| **A** | x86-Gerät mit 16 GB, BIT oder privat | VMware installieren, Abbild importieren. Der Normalfall |
| **B** | MacBook mit M-Prozessor und 16 GB | Fusion installieren, ARM-Abbild importieren |
| **C** | 8 GB Arbeitsspeicher, zu wenig Platz, oder wer sein privates Gerät nicht mitbringen will | Leihgerät vom BIT |

**Entscheidungsregel für Spur B:** Bis zwei Betroffene sind Leihgeräte einfacher. Ab drei
lohnt das ARM-Abbild — es kostet nur noch rund zwei Stunden, seit die Provisionierung ein
einziger Befehl ist.

---

## Schwellenwerte

| | Erforderlich | Empfohlen | Bemerkung |
|---|---|---|---|
| **Arbeitsspeicher** | **16 GB** | 16 GB | Bei 8 GB Leihgerät, siehe oben |
| Kerne | 4 | 4 oder mehr | Bei 2 Kernen wird das Bauen von Agenten zäh |
| Freier Speicherplatz | **60 GB** | 80 GB | |
| Prozessor | x86-64 oder Apple Silicon | | |
| Rechte | lokaler Administrator | | für die Installation von VMware |

**Der Speicherplatz reisst am häufigsten.** Das Abbild ist 8 bis 11 GB, die entpackte VM
wächst im Betrieb auf 30 bis 40 GB. Ein MacBook mit 256 GB, halb voll mit Fotos, hat die
60 GB nicht — und das merkt man mitten im Import, wenn schon zwanzig Minuten vergangen sind.

**Die Kernzahl wird oft übersehen.** Vier virtuelle Prozessoren auf einem Zweikerner sind
langsamer als zwei, weil der Hypervisor ständig umschalten muss.

---

## Der Selbsttest für die Lernenden

Eine Seite, mit der Anmeldung verschickt. Fünf Minuten Aufwand.

### Windows

1. **Prozessor und Arbeitsspeicher.** `Win` + `R`, `msinfo32` eingeben.
   Unter *Systemtyp* muss `x64-basierter PC` stehen. Bei `ARM64` bitte melden.
   *Installierter physischer Speicher* notieren.
2. **Kerne.** Task-Manager, Reiter *Leistung*, *CPU*. Zeile *Kerne* notieren.
3. **Freier Speicherplatz.** Explorer, Laufwerk C, Rechtsklick, *Eigenschaften*.
4. **Virtualisierungsbasierte Sicherheit.** Im `msinfo32`-Fenster danach suchen. Notieren,
   ob dort *Wird ausgeführt* steht.

Punkt 4 ist **kein Blocker**, sondern eine Leistungsfrage. VMware läuft auch mit aktiver
virtualisierungsbasierter Sicherheit, arbeitet dann aber über die Windows-Schnittstellen statt
direkt auf der Hardware. Wir wollen vorher wissen, bei wie vielen Geräten das der Fall ist,
und auf einem davon einmal messen.

### macOS

1. **Apfelmenü → Über diesen Mac.** Steht dort *Apple M1* bis *M4*, kommt ihr in Spur B.
   Steht dort *Intel*, seid ihr in Spur A.
2. Arbeitsspeicher aus demselben Fenster.
3. Freier Speicherplatz: *Über diesen Mac → Weitere Infos → Speicher*.

### Linux

```bash
lscpu | grep -E 'Architecture|Virtualization|^CPU\(s\)'
free -g
df -h /
mokutil --sb-state 2>/dev/null || echo "Secure Boot: unbekannt"
```

Ist Secure Boot aktiv, müssen die VMware-Kernelmodule signiert oder Secure Boot abgeschaltet
werden. Machbar, aber nichts, was man am Kursmorgen zum ersten Mal macht. Bitte vermerken.

---

## Rückmeldebogen

| Frage | Antwort |
|---|---|
| Eigenes Gerät oder BIT-Gerät? | |
| Betriebssystem und Version | |
| Prozessor: x64 oder ARM / Apple M? | |
| Anzahl Kerne | |
| **Arbeitsspeicher in GB** | |
| Freier Speicherplatz in GB | |
| Lokale Administratorrechte vorhanden? | |
| Windows: virtualisierungsbasierte Sicherheit aktiv? | |
| Linux: Secure Boot aktiv? | |
| Ich möchte lieber ein Leihgerät | |

Der Arbeitsspeicher ist hervorgehoben, weil er neu über die Spur entscheidet. Und die letzte
Zeile braucht keine Begründung — niemand muss sein privates Gerät mitbringen.

---

## Spur B: Apple Silicon

VMware Fusion führt auf M-Prozessoren ARM-Gäste aus. Es braucht ein eigenes Abbild, weil sich
Architekturen nicht wegkonfigurieren lassen, aber kein zweites Werkzeug und keine zweite
Anleitung.

**Ab drei Betroffenen ein ARM-Abbild bauen.** Aufwand rund zwei Stunden: VM in Fusion anlegen,
`debian-13.x.0-arm64-netinst.iso` installieren, `setup.sh` vom Host laufen lassen,
exportieren. Der Ablauf ist derselbe wie für x86.

**Drei Punkte beim ersten ARM-Aufbau prüfen.** Sie fallen im Selbsttest sofort auf, aber
besser man weiss vorher davon:

- `onnxruntime` in ChromaDB — fällt es aus, bricht die Suche
- `CTranslate2` in faster-whisper — fällt es aus, scheitert die Transkription der Tonaufnahme
- die ARM-Verfügbarkeit von OpenCode

**VirtualBox ist für Spur B keine Alternative**, auch wenn es inzwischen ein Paket für Apple
Silicon gibt. Laut Handbuch laufen dort keine x86-Gäste, und ARM-Hosts haben Einschränkungen
bei Ton, Grafik und Gasterweiterungen. Der Ton wird für die Abschlussarbeit gebraucht.

---

## Rückfallweg VirtualBox

Nur nötig, falls die Lizenzprüfung bei VMware anders ausgeht oder eine Vorgabe proprietäre
Software auf Lernendengeräten ausschliesst. Dann kommt eine Hürde dazu:

**Auf Windows-Geräten mit aktiver virtualisierungsbasierter Sicherheit muss diese abgeschaltet
werden.** Oracle führt den gemeinsamen Betrieb mit Hyper-V als experimentelle Funktion und
warnt vor schlechter Leistung. Der Haken: Auf neueren Windows-Versionen aktiviert bereits die
Kernisolierung Hyper-V wieder, auch wenn man es zuvor abgeschaltet hat. Oracle verweist dann
auf das Device-Guard-Werkzeug von Microsoft und weist selbst darauf hin, dass dessen Einsatz
die Sicherheit des Hosts beeinträchtigt.

Auf einem BIT-Gerät braucht das die Zustimmung der Client-Verantwortlichen, und die dauert
Wochen. Genau deshalb ist VMware der Hauptweg.

Vollständige Anleitung samt Rückweg: `docs/vm-anlegen.md`.

---

## Private Geräte: was zu klären ist

Die technische Seite ist der einfachere Teil.

**Datenschutz.** Die VM enthält keine BIT-Daten und keine Personendaten, der Schlüssel ist
persönlich und wird nach dem Kurs widerrufen. Damit ist der Betrieb auf einem privaten Gerät
vertretbar. Diese Begründung sollte einmal schriftlich festgehalten sein, bevor jemand sie in
sechs Monaten nachfragt.

**Die Regel bleibt.** Keine BIT-Daten in die VM, egal auf welchem Gerät. Auf einem privaten
Laptop ist sie wichtiger, nicht weniger, und sie gehört auf die Tischkarte.

**Haftung.** Wenn ein privates Gerät während des Anlasses Schaden nimmt, sollte vorher klar
sein, wer dafür aufkommt. Eine Zeile in der Anmeldebestätigung genügt.

**Freiwilligkeit.** Wer sein Gerät nicht mitbringen will, bekommt ein Leihgerät, ohne
Begründung und ohne Nachfrage.

---

## Verteilung des Abbilds

Der Import muss zu Hause passieren. Fünfzehn Minuten Import mal dreissig Personen sind ein
verlorener Morgen.

**Beides anbieten.** Einen Download-Link, der von ausserhalb des BIT-Netzes erreichbar ist,
mit der SHA256-Summe daneben. Und USB-Sticks für alle, deren Anbindung zu Hause 10 GB nicht
in vertretbarer Zeit schafft, ausgegeben eine Woche vorher.

Die Prüfsumme steht auf einem Beiblatt. Ein abgebrochener Download fällt sonst erst nach
zwanzig Minuten Import auf.

---

## Der Testdurchlauf

Zwei Wochen vor dem Kurs, eine Stunde, online.

Jede und jeder startet die VM einmal und führt aus:

```bash
~/bootcamp/scripts/selftest.sh
```

Der Test unterscheidet drei Zustände. **Grün** heisst fertig. **Gelb** heisst offen, aber zu
diesem Zeitpunkt normal — etwa ein noch nicht eingetragener Schlüssel. **Rot** heisst Fehler,
und jeder rote Punkt nennt den nächsten Schritt. Am Ende zeigt der Test Arbeitsspeicher,
Auslagerung und Plattenbelegung.

Wer keine roten Punkte hat, ist fertig und kann gehen.

**Die Rückmeldung ist das Kriterium, nicht die Teilnahme.** Zu solchen Terminen erscheinen
erfahrungsgemäss die, bei denen ohnehin alles läuft. Verlangt einen Screenshot der
Schlusszeilen — dort stehen auch die Speicherwerte, und damit seht ihr sofort, ob die
Zuteilung stimmt.

---

## Zeitplan

Anzupassen an das tatsächliche Kursdatum. Die Abstände sind das Wesentliche.

| Wann | Was | Wer |
|---|---|---|
| **jetzt** | Gerätecheck verschicken, Frist auf zwei Wochen | Bootcamp-Leitung |
| **jetzt** | Auf einem Gerät mit produktivem BIT-Image messen, wie schnell VMware neben aktiver virtualisierungsbasierter Sicherheit läuft | KI-Team |
| + 2 Wochen | Rückmeldungen auswerten, Spuren zuteilen, **Leihgeräte bestellen** | Bootcamp-Leitung |
| + 3 Wochen | x86-Abbild bauen und exportieren, bei Bedarf ARM-Abbild | KI-Team, mit den Lernenden |
| + 4 Wochen | Verteilung vorbereiten: Download, USB-Sticks, Prüfsummen drucken | KI-Team |
| − 2 Wochen | Testdurchlauf | alle |
| − 1 Woche | Nachfassen bei allen ohne Rückmeldung | Bootcamp-Leitung |

Zwei Zeilen lassen sich nicht verschieben. Die Messung entscheidet, ob ihr eine Ausnahme der
Client-Verantwortlichen braucht, und die dauert Wochen. Und die Leihgerätebestellung hängt an
einer Zahl, die erst aus den Rückmeldungen entsteht.

---

## Anhang: Wenn die Leihgeräte knapp werden

Falls die Erhebung mehr 8-GB-Geräte zutage fördert, als Leihgeräte verfügbar sind, gibt es
drei Auswege, in dieser Reihenfolge:

**Die VM auf 6 GB setzen.** Auf einem Host mit 8 GB bleiben dann 2 GB fürs Wirtsystem. Für
Windows 11 zu wenig, für ein schlankes Linux knapp machbar. Nur für Einzelfälle, und vorher
ausprobieren.

**Die Dienste staffeln.** Wer Open WebUI nicht dauernd braucht, schaltet den automatischen
Start ab und gewinnt rund 1 GB. Kostet Bedienkomfort, rettet aber ein Gerät.

**Zu zweit an einem Gerät arbeiten.** Im Kurs wird ohnehin in Teams gearbeitet. Für die
Vorbereitung zu Hause taugt es nicht, an den Kurstagen ist es eine tragfähige Notlösung — und
pädagogisch keine schlechte.

Wovon ich abrate: die Werkzeuge direkt auf dem Wirtsystem installieren. Die identische
Umgebung ist der halbe Wert der ganzen Übung. Sobald drei Leute unterschiedliche
Python-Versionen haben, verbringt die Betreuung den Vormittag mit Fehlersuche statt mit
Inhalt.
