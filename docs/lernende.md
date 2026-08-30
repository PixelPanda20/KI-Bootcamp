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

Danach **sofort einen Sicherungspunkt anlegen**: *VM → Snapshot → Snapshot aufnehmen*, Name
`Startzustand`.

Damit kommst du jederzeit zurück, wenn etwas kaputtgeht. Das wird passieren, und das ist in
Ordnung. Dafür ist eine VM da.

---

## Befehle, die du brauchst

| Befehl | Was passiert |
|---|---|
| `bc` | Python-Umgebung aktivieren, ins Arbeitsverzeichnis wechseln |
| `webui` | Open WebUI starten, Browser öffnet `localhost:3000` |
| `dockergui` | Portainer starten, `localhost:9000`, admin / bootcamp2026 |
| `lzd` | Container im Terminal ansehen |
| `opencode` | Coding-Agent im Terminal |
| `code ~/bootcamp` | VS Code öffnen |
| `ollama run qwen3:1.7b` | lokales Modell, ohne Internet |
| `~/bootcamp/scripts/selftest.sh` | prüft, ob alles läuft |
| `bootcamp-setup` | Schlüssel neu eintragen |

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
| VM ist sehr langsam | Auf dem Host andere Programme schliessen. Bei 8 GB RAM: `sudo systemctl disable --now ollama` |
| Bildschirm passt sich nicht an | VM-Fenster einmal in der Grösse ändern |
| Kein Copy-Paste zum Host | In den VM-Einstellungen die Zwischenablage auf bidirektional |
| `docker: permission denied` | Einmal ab- und wieder anmelden |
| Open WebUI zeigt keine Modelle | Schlüssel prüfen: `bootcamp-setup` |
| Kein Internet im BIT-Netz | `~/bootcamp/scripts/proxy-setup.sh http://proxy:port` |
| Alles kaputt | Sicherungspunkt `Startzustand` wiederherstellen |

Kommst du nicht weiter: frag die Lernenden, die die VM mitgebaut haben. Sie kennen den Aufbau
von innen.
