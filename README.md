# KI-Bootcamp — VM-Konfiguration

Arbeitsumgebung für die Lernenden des BIT. Debian 13 mit GNOME, provisioniert über SSH.

```
setup.sh / setup.ps1        provisioniert die VM. Ein Befehl.
docs/vm-anlegen.md          VM anlegen, Debian installieren, Hypervisor-Hinweise
docs/lernende.md            eine Seite für die Lernenden, zum Ausdrucken
gast/                       wird von setup.sh in die VM übertragen
  provision.sh              richtet alles ein
  requirements-ai.txt       Python-Bibliotheken
  docker-compose.yml        Open WebUI, optional Portainer, Qdrant, n8n
  models.env                Modell-Allowlist
  bootcamp-setup            Ersteinrichtung durch den Lernenden (API-Schlüssel)
  prepare-export.sh         VM für die Verteilung aufräumen
  webui-autostart.sh        Open WebUI beim Anmelden starten (an/aus/status)
  vscode/                   Arbeitsbereichseinstellungen, Aufgaben, Debugger
  desktop/                  Hintergrundbild
  optional/                 wird mitkopiert, aber nicht ausgeführt
```

---

## Ablauf

**1 · VM anlegen und Debian installieren.** Siehe `docs/vm-anlegen.md`. Wichtig: bei der
Installation das Root-Passwort leer lassen, sonst bekommt `bootcamp` keine sudo-Rechte. Bei
der Softwareauswahl GNOME und SSH server anhaken.

**2 · Adresse ermitteln.** In der VM:

```bash
hostname -I
```

**3 · Provisionieren.** Auf dem Host, im Ordner mit diesem Repository:

```bash
./setup.sh 192.168.1.42          # macOS, Linux
.\setup.ps1 192.168.1.42         # Windows
```

40 bis 60 Minuten. Danach in der VM ab- und wieder anmelden, dann
`~/bootcamp/scripts/selftest.sh`.

**4 · Verteilen**, falls ein Abbild für alle gebaut wird:

```bash
~/bootcamp/scripts/prepare-export.sh
sudo poweroff
```

---

## Was in der VM steckt

**Basis** Debian 13 (trixie) mit GNOME auf Wayland, Anmeldung über GDM, Zeitzone
Europe/Zurich, Tastatur Schweizerdeutsch, Systemsprache Englisch, dunkles Erscheinungsbild

**Werkzeuge** VS Code mit vorbereitetem Arbeitsbereich · OpenCode · Continue · Python 3.12 mit uv · Node.js · Docker mit
Compose · lazydocker · Git · promptfoo · ripgrep, fzf, jq, tmux, ffmpeg

**Python** OpenAI-SDK gegen OpenRouter · LangChain, LangGraph, smolagents, pydantic-ai · MCP
und FastMCP · ChromaDB mit ONNX-Embeddings · faster-whisper · Streamlit, Gradio, FastAPI ·
pandas, matplotlib, JupyterLab · deepeval

**Dienste** Open WebUI auf 3000, vorkonfiguriert gegen OpenRouter, startet bei jeder
Anmeldung automatisch. Optional Portainer (`--profile tools`), Qdrant (`--profile rag`),
n8n (`--profile lcnc`).

**Präsentationen** Ein Werkzeug für Open WebUI erzeugt native `.pptx`-Dateien mit
bearbeitbarem Text, Diagrammen und Formen. Es liegt unter `~/bootcamp/tools/` und wird von der
lernenden Person einmalig in Open WebUI importiert — Werkzeuge hängen dort am Benutzerkonto,
und die Vorlage wird bewusst ohne Konto ausgeliefert. Herkunft, Lizenz und Prüfergebnis stehen
in `gast/openwebui-tools/README.md`.

**Open WebUI aktualisieren** `~/bootcamp/scripts/webui-update.sh <version>`. Es schreibt die
neue Kennung in `docker-compose.yml`, sichert vorher die Daten und setzt bei Misserfolg
selbsttätig zurück. Bewusst kein `:latest` — sonst wäre das Pinnen wertlos.

Der Autostart läuft über eine systemd-Benutzereinheit, nicht über `restart: unless-stopped`
in der Compose-Datei. Letzteres startet einen Container zwar nach einem Neustart wieder, aber
nur wenn er vorher schon einmal angelegt wurde — bei einer frisch verteilten VM existiert er
noch gar nicht. Benutzereinheit statt Systemeinheit, weil Open WebUI nur gebraucht wird, wenn
jemand an der VM arbeitet. Aus- und wieder einschalten mit
`~/bootcamp/scripts/webui-autostart.sh aus` beziehungsweise `an`.

**Architekturen** amd64 und arm64. `provision.sh` erkennt Architektur und Hypervisor selbst.

---

## Sieben Entscheide, die vom Naheliegenden abweichen

**Debian statt Ubuntu.** Debian 13 ist seit über einem Jahr gesetzt, während die aktuelle
Ubuntu-LTS erst wenige Wochen alt ist. Für einen einmaligen Anlass mit dreissig Personen ist
die frischeste Version die, die Überraschungen produziert. Dazu kommt: es gibt kein Snap, die
Kernwerkzeuge sind die vertrauten GNU-coreutils statt der Rust-Neufassung, und für ARM
existieren offizielle Installationsabbilder.

**GNOME, so wie der Installer es liefert.** Ursprünglich war XFCE auf X11 vorgesehen, mit dem
Argument von rund 800 MB weniger Arbeitsspeicher. An der fertigen VM gemessen trägt das nicht:
mit laufendem Open WebUI belegt GNOME auf Wayland 1,9 GB von 7,8 GB, der Start dauert 11
Sekunden. Bei 8 GB Zuteilung und aktivem zram ist das kein Engpass — und ein Desktop, den der
Installer ohne Zusatzschritt mitbringt, ist einer weniger, der beim Aufbau schiefgehen kann.
Hintergrundbild, dunkles Erscheinungsbild und abgeschaltete Bildschirmsperre setzt
`desktop-anpassen.sh` per `gsettings` bei der ersten Anmeldung.

**VMware statt VirtualBox.** VMware läuft neben aktiver virtualisierungsbasierter Sicherheit.
Oracle führt den gemeinsamen Betrieb von VirtualBox und Hyper-V als experimentelle Funktion
und warnt vor schlechter Leistung; die Abhilfe verlangt das Abschalten von
Sicherheitsfunktionen, was Oracle selbst als sicherheitsrelevant kennzeichnet. Auf
verwalteten BIT-Geräten wäre das ein Genehmigungsprozess von Wochen. VirtualBox bleibt als
dokumentierter Rückfallweg.

**Provisionierung über SSH statt vorbereiteter Maschinendateien.** Ein Skript für alle
Hypervisoren, statt vier Skripte zu pflegen und zu testen. Nebeneffekt: Apple Silicon braucht
kein zweites vorgefertigtes Abbild, die wenigen Betroffenen legen ihre VM selbst an.

**Python auf 3.12 festgenagelt**, nicht auf die Systemversion. Wheels für `onnxruntime`,
`ctranslate2` und einige Agentenbibliotheken hinken der jeweils neuesten CPython-Version
regelmässig Monate hinterher. uv lädt die passende Version selbst, das kostet einmalig rund
30 MB.

**Kein PyTorch.** ChromaDB bringt ONNX-Embeddings mit, faster-whisper nutzt CTranslate2.
Beides läuft auf der CPU schnell genug und spart zusammen rund 3 GB im Abbild.

**Keine lokalen Sprachmodelle.** Kein Ollama, kein llama.cpp. Auf vier CPU-Kernen ohne
Grafikbeschleunigung wäre nur ein Kleinstmodell lauffähig, dessen Qualität in keinem
Verhältnis zu einer ernsthaften On-Premise-Installation steht. Lernende würden daraus den
falschen Schluss ziehen, lokale Modelle taugten nichts, und diese Fehleinschätzung ins BIT
tragen, wo gerade über souveräne KI-Infrastruktur nachgedacht wird. Spart nebenbei 2 bis 3 GB
im Abbild und 1,5 GB Arbeitsspeicher im Betrieb.

Wenn der Vergleich zwischen fremder und eigener Infrastruktur im Kurs vorkommen soll, gehört
er über einen zweiten API-Schlüssel bei einem Schweizer Anbieter abgebildet, nicht über ein
Spielzeugmodell im Notebook.

---

## Optimierung für den Kursbetrieb

Die VM ist kein Arbeitsplatzrechner. Alles, was nicht dem Kurs dient, ist entfernt oder
abgeschaltet.

**Entfernt:** LibreOffice, Druck- und Scanunterstützung (cups, hplip, simple-scan, xsane),
Bluetooth, ModemManager, der Mailserver exim4, avahi, xfburn, parole, Thunderbird, Spiele
und die Dateiindizierung. Zusammen grob 1 bis 1,5 GB und ein halbes Dutzend Dienste, die
sonst bei jedem Start mitlaufen. Künftig installierte Pakete kommen ohne fremdsprachige
Handbücher und ohne `/usr/share/doc`.

**Abgeschaltet:** `NetworkManager-wait-online` verzögert den Start sonst um bis zu dreissig
Sekunden. Die apt-Zeitgeber greifen sich mitten in einer Übung die Paketsperre, und der
Lernende sieht nur "could not get lock". `man-db` baut nach jeder Paketinstallation
minutenlang seinen Index neu. `fstrim.timer` bleibt bewusst aktiv, weil es freigewordene
Blöcke an den Hypervisor zurückgibt und die Abbilddatei klein hält.

**zram statt Plattenauslagerung.** Der wirksamste Einzeleingriff bei 6 GB: Der
Auslagerungsbereich liegt komprimiert im Arbeitsspeicher (zstd, 50 Prozent). Bei Textdaten
komprimiert das grob im Verhältnis 3:1. Wenn Docker, VS Code und Firefox gleichzeitig
Spitzen erzeugen, federt das ab, statt die VM ins Plattenschlurfen zu schicken. Dazu
`vm.swappiness=150`, weil häufiges Auslagern mit zram erwünscht ist — der Standardwert 60
stammt aus der Zeit rotierender Platten.

**Begrenzte Protokolle.** Containerprotokolle auf 10 MB in drei Dateien, das Systemjournal
auf 100 MB. Ein schwatzhafter Agent, der drei Tage lang Fehler schreibt, füllt sonst die
Platte.

**VS Code** schliesst `.venv` von Dateiwächter, Suche und Analyse aus und rechnet die
Oberfläche ohne Grafikbeschleunigung. Beides ist in einer VM spürbar.

**Firefox** ohne Telemetrie, ohne Pocket, ohne Erstlaufseite, mit Open WebUI als Startseite.

Der Selbsttest zeigt am Ende Arbeitsspeicher, Auslagerung, Plattenbelegung und ob zram läuft.

---

## Schlüssel und Governance

**Kein API-Schlüssel im Abbild.** Er wäre in dreissig Kopien unwiderruflich verteilt.
Stattdessen fragt `bootcamp-setup` beim ersten Start den persönlichen Schlüssel ab, prüft ihn
gegen OpenRouter und legt ihn unter `~/.config/bootcamp/env` mit Modus 600 ab. OpenCode,
Continue, Open WebUI und die Python-Übungen lesen alle aus dieser einen Datei.

**Ein Schlüssel pro Lernendem, mit Ausgabenlimit.** Das Konto gehört dem BIT, die Lernenden
erstellen keine eigenen. Das löst nebenbei die Altersfrage, denn ein Teil der Lernenden ist
minderjährig.

**Zero Data Retention kontoweit erzwingen**, zusammen mit `data_collection: deny`, bevor der
erste Schlüssel ausgegeben wird.

**Die Regel gehört auf die Tischkarte:** Keine BIT-Daten, keine Personendaten, keine
Amtsgeheimnisse in die VM oder in ein Modell. Übungsdaten sind erfunden oder öffentlich.

Nach dem Kurs alle Schlüssel widerrufen. Die VM dürfen die Lernenden behalten.
