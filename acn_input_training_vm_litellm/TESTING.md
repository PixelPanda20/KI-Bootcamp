# Abnahme vor der Verteilung

Durchlauf vor jeder Auslieferung. Dauert rund 20 Minuten und kostet etwa
0.10 USD (zwei Bildgenerierungen, ein paar Chat-Aufrufe).

Abhaken, was stimmt. Ein Punkt, der nicht stimmt, ist ein Auslieferungsstopp —
die meisten hier aufgeführten Prüfungen sind entstanden, weil genau dieser
Fehler schon einmal aufgetreten ist.

---

## 0. Sauberer Ausgangszustand — nicht überspringen

**Der wichtigste Schritt.** Open WebUI liest seine Konfiguration nur beim
allerersten Start aus der Umgebung und schreibt sie dann in die eigene
Datenbank. Wer auf einem gelaufenen Stack testet, prüft den Zustand von
vorgestern und nicht das, was die Teilnehmenden bekommen.

```bash
cd acn_input_training_vm_litellm
make clean          # docker compose down -v — löscht ALLE Volumes

# Volumes des Projekts. Der Präfix folgt COMPOSE_PROJECT_NAME aus der .env
# (Vorgabe: bit_bootcamp) — deshalb hier gelesen statt fest eingetragen.
docker volume ls | grep "$(grep '^COMPOSE_PROJECT_NAME=' .env | cut -d= -f2)_"   # muss leer sein
```

- [ ] Keine Volumes des Projekts mehr vorhanden
- [ ] `.env` vorhanden, `AI_API_KEY` gesetzt
- [ ] `OPENWEBUI_CHAT_KEY` in `.env` gesetzt — **vor** dem ersten Start, sonst
      startet Open WebUI mit dem Master-Key und merkt sich diesen dauerhaft
- [ ] `LITELLM_PORT` frei (`lsof -nP -iTCP:4000 -sTCP:LISTEN`)

---

## 1. Stack starten

```bash
make up
make bootstrap
```

- [ ] `make up` läuft ohne `port is already allocated` durch
- [ ] `make ps` zeigt sechs Container, Postgres und Open WebUI `healthy`
- [ ] `make bootstrap` meldet genau sieben Chat-Modelle
- [ ] `make bootstrap` ein zweites Mal ausführen — meldet
      *„Bestehender Schlüsselwert aus .env wiederverwendet"* und
      *„Bestehender Schlüssel aktualisiert"*, der Wert in `.env` ändert sich nicht

> Bricht LiteLLM ab: `docker compose logs litellm`. Nach einem
> fehlgeschlagenen Port-Bind hängt der Container ohne Netzwerk und startet
> endlos neu — dann `docker compose up -d --force-recreate litellm`, ein
> einfacher Neustart genügt nicht.

---

## 2. Automatische Prüfungen

```bash
make check
make models
cd training && uv run python example_call.py
cd training && uv run python example_call.py --stream
cd .. && make demo-n8n
```

- [ ] `make check` ohne Fehler
- [ ] `make models` listet neun Einträge (sieben Chat + ein Embedding-Modell
      + ein Bildmodell — der Master-Key sieht bewusst mehr als Open WebUI)
- [ ] `example_call.py` liefert eine Antwort
- [ ] `example_call.py --stream` liefert eine Antwort tokenweise
- [ ] `make demo-n8n` endet mit *„Alles in Ordnung"*, Chat-Antwort und
      Bilddatei über 1 MB

---

## 3. Open WebUI im Browser

http://bit-chat

- [ ] Erste Registrierung funktioniert, Konto wird Administrator
- [ ] Modellwähler zeigt **genau sieben** Modelle
- [ ] `google/gemini-2.5-flash-image` ist **nicht** im Modellwähler
- [ ] `arena-model` ist **nicht** im Modellwähler
- [ ] Chat mit dem vorausgewählten Modell liefert eine Antwort
- [ ] Modellwechsel auf ein zweites Modell liefert ebenfalls eine Antwort
- [ ] Bildsymbol in der Eingabezeile erzeugt ein Bild

> Bilder entstehen über das Bildsymbol, nicht über eine Chat-Nachricht.
> *„Erzeuge ein Bild von …"* an ein Textmodell führt korrekterweise zu
> *„I cannot create images"* — das ist kein Fehler.

---

## 4. n8n im Browser

http://bit-n8n

`make demo-n8n` hat Konto, Zugangsdaten und Ablauf bereits angelegt.

- [ ] Anmeldung mit dem Demo-Konto funktioniert
- [ ] Ablauf *„LiteLLM Demo — Chat und Bild"* ist vorhanden
- [ ] Manuelle Ausführung im Editor: beide Nodes werden grün
- [ ] Der Bild-Node zeigt in der Ausgabe eine Binärdatei
- [ ] Ein Webhook-Node zeigt eine Adresse mit `bit-n8n` — **nicht**
      `localhost:5678` und ohne falschen Port

> Zugangsdaten von Hand anlegen: Typ **OpenAI** (nicht OpenRouter),
> Base URL `http://litellm:4000/v1`. Für Bilder reicht `OPENWEBUI_CHAT_KEY`
> **nicht** — der darf nur Chat-Modelle. Siehe README, Abschnitt 8.

---

## 5. LiteLLM-Oberfläche und Kosten

http://bit-litellm/ui — Anmeldung mit `LITELLM_MASTER_KEY`

```bash
make spend
```

- [ ] Anmeldung an der Oberfläche funktioniert
- [ ] `make spend` zeigt eine Zeile `GESAMT (Proxy)` mit dem Deckel aus `.env`
- [ ] Die Schlüssel `open-webui-chat` und `n8n-demo` erscheinen mit Ausgaben
- [ ] Nach erneutem `make bootstrap` sind die Ausgaben **nicht** auf null
      zurückgesetzt

Virtual Key für eine teilnehmende Person prüfen:

```bash
make key NAME=test-01 BUDGET=1
```

- [ ] Ein Schlüssel wird ausgegeben und erscheint in `make spend` mit Budget 1

---

## 6. Vor dem Verteilen

Diese Punkte betreffen das ausgelieferte Abbild, nicht den laufenden Test.

- [ ] `LITELLM_MASTER_KEY` ersetzt — nicht mehr `sk-bit-bootcamp-master`
      (`openssl rand -hex 24`)
- [ ] `OPENWEBUI_CHAT_KEY` ersetzt — nicht mehr `…changeme`
      (`echo "sk-bit-$(openssl rand -hex 16)"`, mindestens 16 Zeichen)
- [ ] Testkonten entfernt: `trainer@bit.local` in Open WebUI **und** n8n,
      oder einfacher `make clean` vor dem Abbild
- [ ] Demo-Schlüssel `sk-bit-n8n-demo-key` (Alias `n8n-demo`) in LiteLLM
      widerrufen — er steht im Klartext in `training/test_n8n_demo.py`, darf
      Chat **und** Bilder und wäre in jeder verteilten Kopie derselbe.
      `make clean` erledigt das mit, weil die LiteLLM-Datenbank im Volume
      liegt; bleibt das Volume bestehen, den Schlüssel unter
      `http://bit-litellm/ui` von Hand löschen
- [ ] `.env` wird **nicht** mitgeliefert — nur `.env.example`
      (`.gitignore` prüfen; das Verzeichnis ist kein Git-Repository, beim
      Kopieren also ausdrücklich ausschliessen)
- [ ] Entschieden, ob `AI_API_KEY` im Abbild liegt: beim Self-Hosting pro
      Person ist es der eigene Schlüssel, beim geteilten Betrieb gehört er
      nur auf den Server
- [ ] `.DS_Store` und `training/.venv` nicht mitkopiert
- [ ] `HTTP_PORT=80` und `LITELLM_PORT=4000` in `.env.example` — die
      abweichenden Werte einer Entwicklungsmaschine dürfen nicht mitreisen

---

## 7. Bekannte Stolpersteine

| Symptom | Ursache | Abhilfe |
|---|---|---|
| Modellwähler leer | Open WebUI meldet sich mit einem gelöschten Schlüssel | `OPENWEBUI_CHAT_KEY` in `.env` muss dem Schlüssel in LiteLLM entsprechen; im Zweifel Volume löschen |
| Modellwähler zeigt neun Modelle | Open WebUI startete ohne `OPENWEBUI_CHAT_KEY` und merkte sich den Master-Key | `.env` ergänzen, Volume von Open WebUI löschen, neu starten |
| Änderung in `.env` wirkt nicht | Open WebUI liest die Umgebung nur beim ersten Start | Volume löschen oder im Admin-Bereich umstellen |
| `make bootstrap` schlägt sofort fehl | LiteLLM war noch mit der Prisma-Migration beschäftigt | behoben durch `wait-litellm`; sonst `docker compose logs litellm` |
| LiteLLM startet endlos neu | Container hängt nach Port-Konflikt ohne Netzwerk | `docker compose up -d --force-recreate litellm` |
| Bild-Node in n8n meldet 401 | Chat-Schlüssel hat keinen Zugriff auf das Bildmodell | Schlüssel mit `IMAGE_MODEL` verwenden, siehe `make demo-n8n` |
| „Invalid key format" | LiteLLM verlangt mindestens 16 Zeichen | längeren Schlüsselwert wählen |
| Alle Sitzungen abgemeldet | Container von Open WebUI wurde neu erstellt | erwartetes Verhalten, neu anmelden |

---

## 8. Noch nicht abgedeckt

Ehrlichkeitshalber — diese Wege sind bisher **nicht** geprüft:

- `config.azure.yaml`: die Azure-Variante ist aufgeschrieben, aber nie gegen
  eine echte Foundry-Ressource gelaufen
- RAG über Open WebUI: `POST /v1/embeddings` liefert geprüft einen Vektor mit
  1536 Dimensionen (README, Abschnitt 10), der Weg darüber hinaus aber nicht —
  Dokument als Knowledge Source hochladen, Chunking, Retrieval im Chat
- Mehrere Personen gleichzeitig auf einer geteilten Installation
- Verhalten bei erschöpftem Budget (HTTP 400) im laufenden Kurs
