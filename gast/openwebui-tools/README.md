# Werkzeuge für Open WebUI

Werkzeuge sind Python-Funktionen, die das Modell in Open WebUI aufrufen kann. Sie laufen
**serverseitig im Open-WebUI-Container** — also in demselben Dienst, der den OpenRouter-Schlüssel
der lernenden Person hält. Deshalb steht hier, was mitgeliefert wird und was geprüft wurde.

---

## generate_slides.py — PowerPoint-Präsentationen

Erzeugt native `.pptx`-Dateien aus einer JSON-Beschreibung, die das Modell selbst schreibt.
Nativ heisst: Text, Diagramme und Formen bleiben in PowerPoint, Keynote und LibreOffice
bearbeitbar. Kein Bild einer Folie, sondern eine echte Folie.

| | |
|---|---|
| Herkunft | https://github.com/ianustec/openwebui-generate-slides |
| Version | 1.0.2 |
| Lizenz | MIT |
| Übernommen am | 30.08.2026 |
| SHA-256 | `e3d45ef9f9610d128875e138ba844d9b3cf1ed4abae0deb20c57cc687d260ee9` |

Rund 25 Layouts (Titel, Abschnitte, Aufzählungen, Spaltenvergleich, Kennzahlen, Zeitstrahl,
Prozessfluss, Symbolgitter, Zitat, Tabellen, Trichter, Pyramide, Kreislauf, Quadrant) sowie
native Office-Diagramme (Balken, Linie, Fläche, Kreis, Ring, Netz, gestapelt).

### Was geprüft wurde

Die Datei hat 2688 Zeilen. Sie ist **nicht Zeile für Zeile gelesen** worden — das wäre eine
Behauptung, die niemand einlösen kann. Geprüft wurde gezielt die sicherheitsrelevante
Oberfläche:

| Prüfung | Ergebnis |
|---|---|
| Codeausführung (`exec`, `eval`, `subprocess`, `pickle`, `os.system`) | **keine** — die Treffer auf „compile" sind allesamt `re.compile` für Markdown |
| Zugriff auf Umgebungsvariablen (`os.environ`, `getenv`) | **keiner** — der API-Schlüssel ist über diesen Weg nicht erreichbar |
| Ausgehende Verbindungen | genau zwei, beide im Bildpfad (`httpx`, Zeilen 943 und 956) |
| URLs im Code | drei: `api.unsplash.com/photos/random` sowie zwei Namensnennungen des Autors, die nicht aufgerufen werden |
| Schreibzugriffe auf die Platte | genau einer (Zeile 1796–1799): das fertige `.pptx` nach `/app/backend/data/cache/files`, also ins Volume |
| `base64` | nur zum **Dekodieren** mitgelieferter Bilder, keine versteckten Blobs |
| Benutzerobjekt | `Users.get_user_by_id` allein, um die Datei über Open WebUIs Files-API dem richtigen Konto zuzuordnen |

Das Ergebnis ist unauffällig. Es ersetzt keine vollständige Prüfung, deckt aber die Wege ab,
über die Daten das System verlassen oder fremder Code zur Ausführung kommen könnte.

### Wichtige Einstellung

Die Stellschraube **`unsplash_access_key` bleibt leer**. Ohne sie holt das Werkzeug keine
Bilder aus dem Netz, und der einzige Weg nach draussen ist zu. Wer Bilder aus Unsplash möchte,
trägt einen eigenen Schlüssel ein und weiss dann, dass Suchbegriffe dorthin abfliessen.

### Abhängigkeiten

Das Werkzeug deklariert `python-pptx` und `pillow` in seiner Frontmatter; Open WebUI
installiert sie beim ersten Laden selbst. Das geschieht **im Container**, und dessen
Dateisystem ist flüchtig: Nach jedem Neuanlegen — `bootcamp-setup` und `webui-update.sh` tun
das — installiert Open WebUI sie erneut. Dafür braucht die VM kurz Zugang zu PyPI.

Praktisch fällt das nicht auf, weil die VM ohnehin ans Netz muss: alle Modelle kommen über
OpenRouter. In einem Netz, das PyPI sperrt, aber OpenRouter erlaubt, schlägt das Laden des
Werkzeugs fehl — dann hilft `~/bootcamp/scripts/proxy-setup.sh`.
