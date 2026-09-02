# KI-Bootcamp — deine VM

Eine Seite. Bitte vor dem Kurs durchgehen.

---

## Vorher, zu Hause

**1 · Gerätecheck ausfüllen.** Vier Fragen, wichtigste zuerst: Hast du ein MacBook mit M1,
M2, M3 oder M4? Dann brauchst du eine andere Anleitung, und wir müssen das jetzt wissen,
nicht im Oktober.

**2 · 60 GB frei machen.** Das Abbild ist rund 12 GB, die VM wächst im Betrieb auf 30 bis
40 GB. Hier klemmt es bei den meisten.

**3 · VMware installieren.** Workstation Pro unter Windows und Linux, Fusion Pro unter
macOS. Beide kostenlos, bei der Lizenzabfrage die freie Nutzung wählen, kein Schlüssel nötig.
Unter macOS musst du die Systemerweiterung freigeben: *Systemeinstellungen → Datenschutz &
Sicherheit*, ganz unten auf **Erlauben**, dann neu starten.

**4 · Abbild importieren.** Datei vom Stick oder aus dem Download, dann öffnen. Dauert 10 bis
15 Minuten.

**5 · Prüfsumme kontrollieren.** Schneller, als später eine kaputte VM zu suchen.

```
Windows:  certutil -hashfile BIT-KI-Bootcamp-v1.ova SHA256
macOS:    shasum -a 256 BIT-KI-Bootcamp-v1.ova
```

Muss mit dem Wert auf dem Beiblatt übereinstimmen.

**6 · VM einmal starten**, damit du weisst, dass sie läuft.

Anmeldung: `bootcamp` / `bootcamp`

---

## Beim ersten Start

Die Ersteinrichtung öffnet sich von selbst und fragt nach deinem persönlichen
OpenRouter-Schlüssel. Den bekommst du am ersten Kurstag.

**Open WebUI startet ab dann bei jeder Anmeldung automatisch** und ist unter
`http://localhost:3000` erreichbar. Beim ersten Mal dauert es eine halbe Minute, bis es
antwortet. Wer den Arbeitsspeicher lieber frei hätte:
`~/bootcamp/scripts/webui-autostart.sh aus`.

Danach **sofort einen Sicherungspunkt anlegen**: *VM → Snapshot → Snapshot aufnehmen*, Name
`Startzustand`.

Damit kommst du jederzeit zurück, wenn etwas kaputtgeht. Das wird passieren, und das ist in
Ordnung. Dafür ist eine VM da.

---

## Befehle, die du brauchst

| Befehl | Was passiert |
|---|---|
| `bc` | Python-Umgebung aktivieren, ins Arbeitsverzeichnis wechseln |
| `webui` | Open WebUI von Hand starten (läuft normalerweise schon) |
| `dockergui` | Portainer starten, `localhost:9000`, admin / bootcamp2026 |
| `lzd` | Container im Terminal ansehen |
| `opencode` | Coding-Agent im Terminal |
| `code ~/bootcamp` | VS Code öffnen — Interpreter, Debugger und Aufgaben sind eingerichtet |
| `~/bootcamp/scripts/selftest.sh` | prüft, ob alles läuft |
| `bootcamp-setup` | Schlüssel neu eintragen |
| `~/bootcamp/scripts/webui-update.sh` | zeigt, welche Open-WebUI-Version läuft; mit Versionsnummer aktualisiert sie |

---

## Präsentationen erzeugen

Open WebUI kann `.pptx`-Dateien schreiben — echte PowerPoint-Folien, in denen Text, Diagramme
und Formen bearbeitbar bleiben, nicht Bilder von Folien. Das Werkzeug dafür liegt in der VM
bereit, muss aber einmalig eingebunden werden. Open WebUI verwaltet Werkzeuge in seiner
Datenbank, und die gehört zu deinem Konto — deshalb kann dir das niemand abnehmen.

**Einmalig, nach dem Anlegen deines Open-WebUI-Kontos:**

1. In Open WebUI oben rechts auf dein Kürzel → **Workspace** → Reiter **Tools**
2. **`+`** → **Import from File**
3. Die Datei `~/bootcamp/tools/generate_slides.py` auswählen
4. Speichern, dann im Chat unten bei **Tools** den Schalter *Generate Slides* einschalten

Beim ersten Aufruf lädt Open WebUI die Pakete `python-pptx` und `pillow` nach. Das dauert
einige Sekunden und braucht einmal Internet.

**Danach genügt eine Ansage im Chat**, zum Beispiel:

> Erstelle eine Präsentation mit acht Folien über Retrieval-Augmented Generation für ein
> Fachpublikum: Titel, Überblick, wie es funktioniert, ein Diagramm zum Vergleich der
> Antwortqualität, Grenzen, Fazit.

Das Modell schreibt die Gliederung, das Werkzeug baut daraus die Datei, und im Chat erscheint
ein Link zum Herunterladen.

**Was du wissen solltest:** Das Werkzeug läuft im Open-WebUI-Dienst, nicht im Modell. Der
Inhalt deiner Folien wird also vom Modell bei OpenRouter erzeugt — wie jede andere Antwort
auch. Bilder holt es standardmässig **nicht** aus dem Netz; dafür wäre ein eigener
Unsplash-Schlüssel nötig, den die Vorlage bewusst nicht enthält.

Herkunft, Lizenz und was daran geprüft wurde, steht in `~/bootcamp/tools/README.md`.

---

## VS Code

Öffne immer den ganzen Ordner mit `code ~/bootcamp`, nicht einzelne Dateien. Nur dann kennt
VS Code die richtige Python-Umgebung und deinen API-Schlüssel.

| Taste | Was passiert |
|---|---|
| `Strg` `Shift` `B` | Open WebUI starten |
| `Strg` `Shift` `P` → *Run Task* | alle übrigen Aufgaben: Portainer, n8n, Selbsttest, Streamlit |
| `F5` | Aktuelle Datei im Debugger starten, mit geladenem Schlüssel |
| `Strg` `L` | Continue fragen, das ist die KI im Editor |

Unten links muss `.venv` als Interpreter stehen. Falls nicht: `Strg` `Shift` `P` →
*Python: Select Interpreter* → den Eintrag mit `.venv` wählen.

---

## Spielregeln

**Keine BIT-Daten in die VM.** Keine Personendaten, keine internen Dokumente, keine
Amtsgeheimnisse — weder in Dateien noch in einen Prompt. Was du an ein Modell schickst,
verlässt die Schweiz. Übungsdaten sind erfunden oder öffentlich.

**Dein Schlüssel gehört dir allein.** Nicht weitergeben, nicht in Git committen, nicht in
einen Chat kopieren. Er hat ein Guthabenlimit; ist es aufgebraucht, melde dich bei der
Betreuung, statt selbst einen neuen zu besorgen.

**Die VM darfst du behalten.** Sie ist auch für die Vertiefungstage und die IPA-Vorbereitung
nützlich. Der Schlüssel wird nach dem Kurs deaktiviert.

---

## Wenn etwas nicht geht

| Problem | Das hilft |
|---|---|
| VM startet nicht, Meldung zu Virtualisierung | Bei der Bootcamp-Leitung melden, nicht selbst herumschrauben |
| VM ist sehr langsam | Auf dem Host andere Programme schliessen. Nicht gebrauchte Dienste beenden: `cd ~/bootcamp/docker && docker compose down` |
| Bildschirm passt sich nicht an | VM-Fenster einmal in der Grösse ändern |
| Kein Copy-Paste zum Host | In den VM-Einstellungen die Zwischenablage auf bidirektional |
| `docker: permission denied` | Einmal ab- und wieder anmelden |
| Open WebUI zeigt keine Modelle | Schlüssel prüfen: `bootcamp-setup` |
| Open WebUI antwortet nicht | `~/bootcamp/scripts/webui-autostart.sh status` |
| Kein Internet im BIT-Netz | `~/bootcamp/scripts/proxy-setup.sh http://proxy:port` |
| Open WebUI meldet eine neue Version | Nicht in der Oberfläche aktualisieren — das Abbild ist absichtlich festgelegt. Der Weg: `~/bootcamp/scripts/webui-update.sh <version>` |
| Alles kaputt | Sicherungspunkt `Startzustand` wiederherstellen |

Kommst du nicht weiter: frag die Lernenden, die die VM mitgebaut haben. Sie kennen den Aufbau
von innen.
