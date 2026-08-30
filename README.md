# KI-Bootcamp — VM-Konfiguration

Arbeitsumgebung für die Lernenden des BIT. Debian 13 mit XFCE, provisioniert über SSH.

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
  desktop/                  Hintergrundbild
  optional/                 wird mitkopiert, aber nicht ausgeführt
```

---

## Ablauf

**1 · VM anlegen und Debian installieren.** Siehe `docs/vm-anlegen.md`. Wichtig: bei der
Installation das Root-Passwort leer lassen, sonst bekommt `bootcamp` keine sudo-Rechte. Bei
der Softwareauswahl Xfce und SSH server anhaken.

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

**Basis** Debian 13 mit XFCE auf X11, Zeitzone Europe/Zurich, Tastatur Schweizerdeutsch,
Systemsprache Englisch, dunkles Erscheinungsbild

**Werkzeuge** VS Code · OpenCode · Continue · Python 3.12 mit uv · Node.js · Docker mit
Compose · lazydocker · Git · promptfoo · ripgrep, fzf, jq, tmux, ffmpeg

**Python** OpenAI-SDK gegen OpenRouter · LangChain, LangGraph, smolagents, pydantic-ai · MCP
und FastMCP · ChromaDB mit ONNX-Embeddings · faster-whisper · Streamlit, Gradio, FastAPI ·
pandas, matplotlib, JupyterLab · deepeval

**Dienste** Open WebUI auf 3000, vorkonfiguriert gegen OpenRouter. Optional Portainer
(`--profile tools`), Qdrant (`--profile rag`), n8n (`--profile lcnc`). Ollama mit einem
Kleinmodell im Standardprofil.

**Architekturen** amd64 und arm64. `provision.sh` erkennt Architektur und Hypervisor selbst.

---

## Sechs Entscheide, die vom Naheliegenden abweichen

**Debian statt Ubuntu.** Debian 13 ist seit über einem Jahr gesetzt, während die aktuelle
Ubuntu-LTS erst wenige Wochen alt ist. Für einen einmaligen Anlass mit dreissig Personen ist
die frischeste Version die, die Überraschungen produziert. Dazu kommt: XFCE ist im Installer
wählbar, es gibt kein Snap, die Kernwerkzeuge sind die vertrauten GNU-coreutils statt der
Rust-Neufassung, und für ARM existieren offizielle Installationsabbilder.

**XFCE statt GNOME.** Rund 800 MB weniger Arbeitsspeicher, und es läuft auf X11. In einer VM
mit 6 GB, in der Docker, Ollama, VS Code und ein Agenten-Verbund gleichzeitig laufen, ist das
der Abstand zwischen komfortabel und Auslagerungsdatei. X11 sorgt zudem dafür, dass sich die
VM unter jedem Hypervisor gleich verhält, statt unter Wayland je nach Hypervisor anders.

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
