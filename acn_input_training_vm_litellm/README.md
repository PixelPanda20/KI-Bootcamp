# ACN Input — Workshop-VM

Input der Accenture AG an das BIT für das KI-Bootcamp.

> **Zweck dieses Pakets.** Es beschreibt die Infrastruktur, auf der die
> Kursunterlagen entstehen — die Entwicklungsumgebung von Accenture, hier als
> lauffähiger Stand dokumentiert. Es ist ein **Ausgangspunkt, kein fertiges
> Abbild**: Umsetzung, Härtung und Verteilung erfolgen in der Umgebung des BIT
> und nach dessen Vorgaben. Die Kursdateien (Übungen, Demos, Notebooks) sind
> noch nicht enthalten und folgen separat; das Paket ist so aufgebaut, dass sie
> später ohne Änderung an der Infrastruktur hinzukommen können.

---

## 1. Inhalt

> **Aufbau.** Der Zugang zu den Modellen läuft über
> [LiteLLM](https://docs.litellm.ai/) als LLM-Proxy: ein Gateway zwischen den
> Kursanwendungen und dem Provider. Was es leistet, steht in Abschnitt 4.

| Pfad | Zweck |
|---|---|
| `docker-compose.yml` | Definition des gesamten Stacks |
| `.env.example` | Konfigurationsvorlage, nach `.env` kopieren |
| `services/litellm/config.yaml` | Modellkatalog OpenRouter — zugleich die Allowlist |
| `services/litellm/config.azure.yaml` | Modellkatalog Azure AI Foundry |
| `training/pyproject.toml`, `uv.lock` | Python-Abhängigkeiten, exakt gepinnt (226 Pakete) |
| `training/.python-version` | Pin auf Python 3.12 |
| `training/check_setup.py` | Prüft Pakete, Stack, Datenbank und Provider |
| `training/example_call.py` | Beispielaufruf über LiteLLM, mit und ohne Streaming |
| `training/test_n8n_demo.py` | Rauchtest n8n gegen Chat- und Bildmodell (`make demo-n8n`) |
| `training/n8n_beispiel_workflow.json` | n8n-Ablauf zum Importieren: Chat erzeugt Bildprompt, Bildmodell erzeugt das Bild |
| `Makefile` | Betriebskommandos |
| `TESTING.md` | Abnahmeliste, Schritt für Schritt vor der Verteilung |

> **Empfehlung: `provision.sh`.** Ein Provisionierungsskript für die Ziel-VM
> (Docker CE installieren, `/etc/hosts`-Einträge schreiben, `.env` anlegen) ist
> nicht enthalten — das liegt in der Verantwortung des BIT, da Laufzeitumgebung
> und Härtungsanforderungen bekannt sind. `make hosts` deckt den `/etc/hosts`-Teil
> ab und kann als Vorlage dienen.

## 2. Schnellstart

```bash
cp .env.example .env      # API-Key eintragen
make hosts                # bit-chat/bit-n8n/bit-litellm -> 127.0.0.1 (sudo)
make up                   # Stack starten
make bootstrap            # einmalig: Chat-Schlüssel für Open WebUI
make install              # Python-Umgebung erstellen
make check                # Umgebung prüfen
```

`make bootstrap` ist nicht optional, wenn der Modellwähler sauber aussehen
soll — die Begründung steht in Abschnitt 6.

`make install` benötigt kein System-Python: `uv` liest `training/.python-version`
und lädt eine eigenständige CPython 3.12. Das Paket ist damit unabhängig davon,
welche Python-Version die Distribution mitbringt — relevant, weil Ubuntu 24.04
mit 3.12 und Debian 13 mit 3.13 ausliefert.

## 3. Dienste

| Dienst | Image | Adresse | Zweck |
|---|---|---|---|
| Caddy | `caddy:2.11.4-alpine` | Port 80 | Reverse Proxy, einziger offener Port |
| Open WebUI | `open-webui:0.11.1` | `http://bit-chat` | Chat- und Bildoberfläche |
| n8n | `n8nio/n8n:2.36.9` | `http://bit-n8n` | Low-Code-Automatisierung |
| n8n Task Runner | `n8nio/runners:2.36.9` | intern | Code-Ausführung für n8n |
| LiteLLM | `litellm-database:v1.100.0` | `http://bit-litellm` | LLM-Proxy: Modelle, Budget, Schlüssel |
| PostgreSQL | `pgvector/pgvector:pg17` | `localhost:5432` | n8n, Vector Store, LiteLLM |

**Es laufen keine Modelle lokal.** Die gesamte Inferenz geht an einen externen
Provider; die VM benötigt keine GPU.

Die LiteLLM-Oberfläche liegt unter `http://bit-litellm/ui`; Passwort ist der
`LITELLM_MASTER_KEY`. Dort sind Ausgaben pro Schlüssel, Fehlerraten und die
letzten Requests einsehbar.

## 4. Warum ein Gateway

Open WebUI, n8n und eigener Code könnten den Provider auch direkt ansprechen.
Der Proxy dazwischen leistet fünf Dinge, die sonst jede Anwendung für sich
lösen müsste: `services/litellm/config.yaml` ist die **Allowlist** — was dort
nicht steht, existiert für den Kurs nicht; der **Kostendeckel** gilt in USD
über einen Zeitraum und erfasst Chat und Bilder gemeinsam; die **Ausgaben**
sind pro Schlüssel, Modell und Request einsehbar statt nur als Gesamtguthaben
beim Provider; **Virtual Keys** geben jeder teilnehmenden Person einen eigenen,
widerrufbaren Schlüssel mit eigenem Budget (Abschnitt 7); und `model_list` darf
**mehrere Provider gleichzeitig** enthalten — Azure für Produktivmodelle,
OpenRouter für den Modellvergleich an Tag 1. Der Provider-Schlüssel bleibt
dabei im Container und erreicht keinen Browser.

**Zur Bildgenerierung.** Open WebUI ruft für Bilder immer
`{base}/images/generations` auf, OpenRouter bedient diesen Pfad nicht. LiteLLM
übersetzt das intern: statt auf `/api/v1/images` umzuschreiben, schickt es eine
gewöhnliche Chat-Completion mit `image_config` und liest das Bild aus
`message.images[]` der Antwort. Für den Stack ist nur das Ergebnis relevant:
der OpenAI-Pfad funktioniert, und zwar geprüft — ein Testaufruf gegen
`google/gemini-2.5-flash-image` lieferte ein gültiges PNG und wurde mit
0.0387 USD korrekt verbucht.

**Was dagegen spricht.** Das `-database`-Image ist mit rund 1 GB deutlich
grösser als die schlanke LiteLLM-Variante ohne Datenbank, und der Start dauert
länger, weil Prisma erst die Datenbank migriert. Für eine VM, die
einmal gebaut und dann verteilt wird, fällt das kaum ins Gewicht; für eine
Umgebung, die häufig neu hochgefahren wird, ist es spürbar.

## 5. Konfiguration

Die Modelle stehen in `services/litellm/config.yaml`, alles Übrige in `.env`.
Diese Trennung ist der Kern der Konfiguration: **was nicht in `config.yaml`
steht, existiert für Open WebUI nicht.** Eine zusätzliche Allowlist auf Seite
von Open WebUI ist deshalb nicht nötig.

| Variable | Bedeutung |
|---|---|
| `AI_API_KEY` | Schlüssel des Providers. Bleibt im LiteLLM-Container |
| `LITELLM_MASTER_KEY` | Zugang zu Proxy und Oberfläche. Vor Verteilung ersetzen |
| `LITELLM_CONFIG` | `config.yaml` (OpenRouter) oder `config.azure.yaml` |
| `CHAT_MODEL`, `DEFAULT_MODELS`, `MODEL_ORDER_LIST` | Vorauswahl und Sortierung |
| `IMAGE_MODEL` | Bildmodell; muss in der Konfiguration `mode: image_generation` haben |
| `EMBEDDING_MODEL` | Embedding-Modell für RAG; muss in der Konfiguration `mode: embedding` haben |
| `LITELLM_MAX_BUDGET_USD` | Ausgabendeckel des gesamten Proxys |

Provider wechseln heisst jetzt: `LITELLM_CONFIG=config.azure.yaml` setzen und
in dieser Datei die Deployment-Namen eintragen. Beide Provider gleichzeitig
sind erlaubt — relevant für den Modellvergleich an Tag 1, weil Nemotron und
die chinesischen Modelle auf der Azure-OpenAI-Fläche fehlen.

## 6. Der Modellwähler und `make bootstrap`

`GET /v1/models` liefert das, was der **anfragende Schlüssel** benutzen darf.
LiteLLM kennt kein "aus der Liste ausblenden"; gefiltert wird ausschliesslich
über Rechte. Mit dem Master-Key erscheinen deshalb neun Modelle — die sieben
Chat-Modelle, das Bildmodell und das Embedding-Modell. Die beiden letzten haben
im Chat-Modellwähler nichts zu suchen.

`make bootstrap` legt einen Schlüssel an, der nur die Modelle mit `mode: chat`
darf, und trägt ihn als `OPENWEBUI_CHAT_KEY` in die `.env` ein. Die Liste wird
aus dem laufenden Proxy gelesen und bleibt damit automatisch in
Übereinstimmung mit `config.yaml`. Bilder laufen weiter über einen eigenen
Schlüssel (`IMAGES_OPENAI_API_KEY`) und sind davon nicht betroffen.

Ohne diesen Schritt läuft der Stack, der Modellwähler zeigt aber zusätzlich
das Bild- und das Embedding-Modell.

## 7. Virtual Keys — ein Schlüssel pro Teilnehmendem

Der Fall, für den sich LiteLLM langfristig rechnet: **eine Infrastruktur,
viele Teilnehmende.** Statt den Provider-Schlüssel zu verteilen, bekommt jede
Person einen eigenen, widerrufbaren Schlüssel mit eigenem Budget. Der
OpenRouter-Schlüssel bleibt im Container und erreicht keinen Browser.

```bash
make key NAME=teilnehmer-01 BUDGET=5     # 5 USD über 30 Tage
make spend                               # Verbrauch pro Schlüssel
```

Ist das Budget erschöpft, antwortet der Proxy mit HTTP 400 und nennt den
Grund; die übrigen Schlüssel laufen weiter. Widerrufen geht über die
Oberfläche unter `http://bit-litellm/ui` oder `DELETE /key/delete`.

> **Hinweis zum Schlüssel.** Wird `AI_API_KEY` im Golden Image hinterlegt, ist
> er in jeder verteilten Kopie enthalten. Beim Self-Hosting pro Person bleibt
> das so — dort ist der Schlüssel ohnehin der eigene. Beim geteilten Betrieb
> ist der Provider-Schlüssel nur auf dem Server, und die Teilnehmenden
> bekommen Virtual Keys.

## 8. Drei Wege zum Modell

Open WebUI, n8n und eigener Code sprechen dieselbe OpenAI-kompatible
Schnittstelle und benutzen denselben Schlüssel. Der OpenRouter-Schlüssel ist in
keinem der drei Fälle beteiligt — er bleibt im LiteLLM-Container.

| Weg | Adresse | Schlüssel |
|---|---|---|
| Open WebUI | intern `http://litellm:4000/v1` | `OPENWEBUI_CHAT_KEY` |
| n8n | intern `http://litellm:4000/v1` | `OPENWEBUI_CHAT_KEY` oder Virtual Key |
| Python / curl | vom Host `http://127.0.0.1:${LITELLM_PORT}/v1` | dito |

### Open WebUI

Nach `make up` und `make bootstrap` fertig konfiguriert. Der erste registrierte
Account wird Administrator. Der Modellwähler zeigt genau die sieben
Chat-Modelle; das Bildmodell fehlt dort bewusst und erscheint stattdessen unter
*Bild erzeugen*.

### n8n

n8n braucht die Zugangsdaten **einmalig von Hand** — sie liegen in der
n8n-Datenbank, nicht in der `.env`:

1. `http://bit-n8n` öffnen, Konto anlegen
2. **Credentials → Create Credential**
3. Als Typ **OpenAI** wählen — *nicht* OpenRouter. Gegenüber n8n ist der
   Anbieter unsichtbar: gesprochen wird mit dem Proxy, nicht mit OpenRouter.
4. Eintragen:
   - **API Key**: der Wert von `OPENWEBUI_CHAT_KEY` aus der `.env`
   - **Base URL**: `http://litellm:4000/v1`
5. Speichern. Danach kann der Node *Message a Model* — wie jeder Agent-Node —
   diese Zugangsdaten verwenden. Als Modell einen der sieben Namen eintragen,
   z. B. `google/gemini-2.5-flash`.

`training/n8n_beispiel_workflow.json` ist ein fertiger Ablauf zum Importieren
(**Workflows → Import from File**): Chat-Modell schreibt einen Bildprompt,
Bildmodell macht daraus ein Bild. Die Zugangsdaten müssen nach dem Import
einmal an beiden Nodes ausgewählt werden: Credential-IDs sind pro Installation
verschieden und stehen deshalb nicht in der Datei.

> **Für Bilder reicht der Bootstrap-Schlüssel nicht.** `OPENWEBUI_CHAT_KEY`
> darf ausschliesslich die Chat-Modelle — genau deswegen bleibt das Bildmodell
> aus dem Modellwähler von Open WebUI heraus. Wer in n8n Bilder erzeugen will,
> braucht einen Schlüssel, der zusätzlich `IMAGE_MODEL` einschliesst.
> `make demo-n8n` legt einen solchen Schlüssel unter dem Alias `n8n-demo` an.

#### Rauchtest

```bash
make demo-n8n
```

Legt den Schlüssel, die Zugangsdaten und den Ablauf an, führt ihn aus und
prüft beide Ergebnisse — Text und Bilddatei. Beantwortet in einem Durchlauf,
ob n8n den Proxy erreicht und ob beide Modellarten funktionieren. Kostet einen
Bildaufruf (~0.04 USD). Wiederholbar: gleichnamige Reste früherer Läufe werden
vorher entfernt.

Nutzt standardmässig das n8n-Konto `trainer@bit.local`; abweichend über
`N8N_DEMO_EMAIL` und `N8N_DEMO_PASSWORD` setzbar.

### Python

```bash
cd training && uv run python example_call.py
cd training && uv run python example_call.py --stream
```

`training/example_call.py` liest Port, Modell und Schlüssel aus der `.env` und
zeigt beide Betriebsarten. Gedacht als Vorlage für eigene Skripte.

## 9. Nicht enthalten

Kursunterlagen (Übungen, Demos, Notebooks, Beispieldaten), Trainer-Material,
die Abnahmeskripte und das VM-Provisionierungsskript. `training/` enthält
bewusst nur das Gerüst der Python-Umgebung, sodass die VM bereits vollständig
gebaut und geprüft werden kann, bevor die Kursunterlagen vorliegen.

## 10. Geprüfter Stand

Der Stack wurde vollständig hochgefahren und gegen OpenRouter getestet — der
Durchgang unten auf einem frischen Open-WebUI-Volume, also im Zustand einer
neu ausgelieferten VM:

| Prüfung | Ergebnis |
|---|---|
| `docker compose config` | valide |
| Alle sechs Container | laufen, Postgres und Open WebUI melden `healthy` |
| `GET /v1/models` mit Chat-Schlüssel | genau die sieben Chat-Modelle |
| Modellwähler in Open WebUI, erster Start | genau sieben Modelle, kein Bildmodell |
| Chat über Open WebUI | Antwort korrekt |
| Chat über n8n (*Message a Model*) | Antwort korrekt, 922 ms |
| Chat über `example_call.py` | Antwort korrekt, ohne und mit Streaming |
| Bildgenerierung über Open WebUI | HTTP 200, PNG 1024×1024, 978 KB |
| `POST /v1/embeddings` mit Master-Key | Vektor mit 1536 Dimensionen |
| Ausgabenerfassung | verbucht, Bild mit 0.0387 USD |
| Budget aus `.env` | proxy-weit aktiv: `spend 0.0395 / max_budget 25.0` |
| `make bootstrap` zweimal nacheinander | idempotent, gleicher Schlüsselwert |

> **Erfahrung aus diesen Tests.** Open WebUI liest seine Konfiguration nur beim
> allerersten Start aus der Umgebung und schreibt sie dann in die eigene
> Datenbank. Spätere Änderungen an `.env` oder `docker-compose.yml` wirken
> nicht mehr — sichtbar wird das erst nach `docker volume rm …_open_webui_data`.
> Beim Bauen eines Golden Image ist das unkritisch, beim Nachjustieren einer
> laufenden Installation die häufigste Fehlerquelle.

`uv sync --frozen` erstellt reproduzierbar eine Umgebung mit Python 3.12.12
und 226 Paketen. Ein vollständiger Provisionierungslauf auf der Ziel-VM steht
beim BIT aus.

Offen: Der Standard-Port 4000 von LiteLLM kollidiert leicht mit anderen
Diensten (SSH-Tunnel, lokale Entwicklungsserver). Auf der Testmaschine musste
`LITELLM_PORT` auf 4001 ausweichen. Betrifft nur den Zugriff vom Host — im
Compose-Netz bleibt es 4000.
