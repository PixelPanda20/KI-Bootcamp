# KI-Bootcamp — Konfiguration

Nur die Konfiguration. Host und Gast, ohne Programminhalte.

```
host/                      Was auf dem Laptop eingerichtet wird
  laptop-vorbereiten.md    Anforderungen, Vorbereitung je Betriebssystem, VM-Einstellungen
  vm-erstellen.sh          VM anlegen (macOS/Linux-Host)
  vm-erstellen.ps1         dasselbe für Windows-Hosts

gast/                      Was in der VM eingerichtet wird
  provision.sh             vollständige Provisionierung
  requirements-ai.txt      Python-Bibliotheken
  docker-compose.yml       Open WebUI, optional Qdrant und n8n
  models.env               Modell-Allowlist
  bootcamp-setup           Ersteinrichtung durch den Lernenden (API-Schlüssel)
  prepare-export.sh        VM für den OVA-Export aufräumen
```

---

## Reihenfolge

**Einmalig, durch das Aufbauteam**

```bash
# 1  Host vorbereiten            → host/laptop-vorbereiten.md
# 2  VM anlegen
./host/vm-erstellen.sh ~/Downloads/xubuntu-24.04.3-desktop-amd64.iso

# 3  Xubuntu installieren
#      Benutzer bootcamp / Passwort bootcamp / Rechner bit-ki-bootcamp
#      Tastatur Schweiz, Systemsprache English
# 4  Guest Additions im Gast installieren, neu starten

# 5  Konfiguration in den Gast kopieren und provisionieren
scp gast/* bootcamp@vm:~/
chmod +x provision.sh && ./provision.sh 2>&1 | tee ~/provision.log

# 6  Abnahme
~/bootcamp/scripts/selftest.sh

# 7  Für den Export aufräumen, dann herunterfahren
./prepare-export.sh && sudo poweroff

# 8  Auf dem Host kompaktieren und exportieren
VBoxManage modifymedium disk ~/VirtualBox\ VMs/bit-ki-bootcamp/bit-ki-bootcamp.vdi --compact
VBoxManage export bit-ki-bootcamp -o BIT-KI-Bootcamp-2026-v1.ova \
    --vsys 0 --product "BIT KI-Bootcamp 2026" --vendor "BIT"
sha256sum BIT-KI-Bootcamp-2026-v1.ova > BIT-KI-Bootcamp-2026-v1.sha256
```

**Pro Lernendem**

Laptop vorbereiten, OVA importieren, Prüfsumme vergleichen, Snapshot anlegen,
`bootcamp-setup` durchlaufen, Selbsttest.

---

## Was in der VM steckt

**Basis** Xubuntu 24.04 LTS (XFCE auf X11), Zeitzone Europe/Zurich, Tastatur Schweiz,
Systemsprache Englisch

**Werkzeuge** VS Code · OpenCode · Continue · Python 3.12 mit uv · Node.js 22 · Docker mit
Compose · Git und GitHub CLI · Firefox als Systempaket · ripgrep, fzf, jq, tmux

**Python** OpenAI-SDK gegen OpenRouter · LangChain, LangGraph, smolagents, pydantic-ai · MCP
und FastMCP · ChromaDB mit ONNX-Embeddings · faster-whisper · Streamlit, Gradio, FastAPI ·
pandas, matplotlib, JupyterLab · promptfoo und deepeval

**Dienste** Open WebUI auf Port 3000, vorkonfiguriert gegen OpenRouter. Optional Qdrant
(`--profile rag`) und n8n (`--profile lcnc`). Ollama mit einem Kleinmodell im Standardprofil.

---

## Drei Entscheide, die vom Naheliegenden abweichen

**Xubuntu statt Ubuntu Desktop.** GNOME ist unter VirtualBox zäh, und Wayland bricht
Zwischenablage und automatische Grössenanpassung. XFCE auf X11 spart rund 1 GB
Arbeitsspeicher und läuft flüssig.

**Kein PyTorch.** ChromaDB bringt ONNX-Embeddings mit, faster-whisper nutzt CTranslate2.
Beides läuft auf der CPU schnell genug und spart zusammen rund 3 GB im Abbild. Bei
Verteilung an dreissig Lernende ist das spürbar. Wer lokale Modelle will, nimmt Ollama.

**Kein Schlüssel im Abbild.** Ein API-Schlüssel im OVA wäre in dreissig Kopien unwiderruflich
verteilt. Stattdessen fragt `bootcamp-setup` beim ersten Start den persönlichen Schlüssel ab,
prüft ihn und legt ihn unter `~/.config/bootcamp/env` mit Modus 600 ab. OpenCode, Continue,
Open WebUI und die Python-Übungen lesen alle aus dieser einen Datei.
