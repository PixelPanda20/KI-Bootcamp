## BIT KI-Bootcamp — infrastructure package (LiteLLM variant)
##   make install    install uv + create the Python environment in training/
##   make check      verify the environment (packages, stack, database, provider)
##   make demo-n8n   smoke-test n8n against chat + image models (costs ~0.04 USD)
##   make hosts      map bit-chat/bit-n8n/bit-litellm to 127.0.0.1 (needs sudo)
##   make up         start the Docker stack
##   make down       stop the stack (volumes are kept)
##   make bootstrap  issue the chat-scoped key for Open WebUI (once, after up)
##   make models     list the models LiteLLM currently exposes
##   make key        issue a virtual key for one participant (BUDGET=5 NAME=…)
##   make spend      show spend per key
##   make logs       follow the logs of all services
##   make ps         show container status
##   make clean      stop the stack and delete all volumes
##   make clean-py   remove Python bytecode and caches

.PHONY: install check demo-n8n hosts up down wait-litellm bootstrap models key spend logs ps clean clean-py

# Der Master-Key aus der .env. Wird für die Verwaltungsaufrufe unten
# gebraucht; ohne .env fällt er auf den Vorgabewert zurück.
LITELLM_MASTER_KEY ?= $(shell grep -E '^LITELLM_MASTER_KEY=' .env 2>/dev/null | cut -d= -f2-)
LITELLM_MASTER_KEY := $(if $(LITELLM_MASTER_KEY),$(LITELLM_MASTER_KEY),sk-bit-bootcamp-master)
LITELLM_PORT ?= $(shell grep -E '^LITELLM_PORT=' .env 2>/dev/null | cut -d= -f2-)
LITELLM_PORT := $(if $(LITELLM_PORT),$(LITELLM_PORT),4000)
LITELLM_URL := http://127.0.0.1:$(LITELLM_PORT)

# Projektname des Stacks. "make clean" filtert die Volumes danach; der Wert
# muss deshalb dem COMPOSE_PROJECT_NAME aus der .env folgen.
COMPOSE_PROJECT_NAME ?= $(shell grep -E '^COMPOSE_PROJECT_NAME=' .env 2>/dev/null | cut -d= -f2-)
COMPOSE_PROJECT_NAME := $(if $(COMPOSE_PROJECT_NAME),$(COMPOSE_PROJECT_NAME),bit_bootcamp)

# ---------------------------------------------------------------------------
# Python environment
# ---------------------------------------------------------------------------
# uv reads training/.python-version and downloads a standalone CPython 3.12,
# independent of the Python version the distribution ships.
install:
	@if ! command -v uv >/dev/null 2>&1; then \
		echo "==> Installing uv …"; \
		curl -LsSf https://astral.sh/uv/install.sh | sh; \
	fi
	cd training && uv sync --frozen
	@echo ""
	@echo "  Ready. Verify with:   make check"

check:
	cd training && uv run python check_setup.py

# Rauchtest über n8n: legt einen Demo-Ablauf an, lässt ihn laufen und prüft,
# dass Chat- UND Bildmodell antworten. Kostet einen Bildaufruf (~0.04 USD).
# Wiederholbar: gleichnamige Reste werden vorher entfernt.
demo-n8n:
	cd training && uv run python test_n8n_demo.py

# ---------------------------------------------------------------------------
# Docker stack
# ---------------------------------------------------------------------------
# provision.sh does this on the VM. Only needed on other machines.
hosts:
	@if grep -q '^# BIT KI-Bootcamp$$' /etc/hosts; then \
		echo "==> Already present in /etc/hosts:"; \
		grep -A1 '^# BIT KI-Bootcamp$$' /etc/hosts; \
	else \
		echo "==> Adding bit-chat, bit-n8n, bit-litellm to /etc/hosts (sudo) …"; \
		printf '# BIT KI-Bootcamp\n127.0.0.1\tbit-chat bit-n8n bit-litellm\n' \
			| sudo tee -a /etc/hosts >/dev/null; \
		echo "    done"; \
	fi

up:
	docker compose up -d
	@echo ""
	@echo "  Open WebUI:  http://bit-chat          (erster Account wird Admin)"
	@echo "  n8n:         http://bit-n8n           nach \"make demo-n8n\": trainer@bit.local / BitBootcamp2026"
	@echo "                                        (vor der Verteilung entfernen, siehe TESTING.md 6)"
	@echo "  LiteLLM:     http://bit-litellm/ui    $(LITELLM_MASTER_KEY)"
	@echo ""
	@echo "  Names not resolving? Run:  make hosts"

down:
	docker compose down

# ---------------------------------------------------------------------------
# LiteLLM operations
# ---------------------------------------------------------------------------
# Was der Modellwähler in Open WebUI zeigt. Erste Anlaufstelle, wenn ein
# Modell fehlt: steht es hier nicht, steht es nicht in config.yaml.
models:
	@curl -sS $(LITELLM_URL)/v1/models \
		-H "Authorization: Bearer $(LITELLM_MASTER_KEY)" \
	| python3 -c "import sys,json;[print(m['id']) for m in json.load(sys.stdin)['data']]"

# Beim ersten Start legt LiteLLM zuerst sein Datenbankschema an
# (Prisma-Migration). Bis das durch ist, lehnt der Port jede Verbindung ab —
# "make bootstrap" direkt nach "make up" lief deshalb bisher ins Leere.
wait-litellm:
	@printf "==> Warte auf LiteLLM ($(LITELLM_URL)) "; \
	for i in $$(seq 1 60); do \
		if curl -sf -m 2 $(LITELLM_URL)/health/liveliness >/dev/null 2>&1; then \
			echo " bereit"; exit 0; \
		fi; \
		printf "."; sleep 2; \
	done; \
	echo ""; \
	echo "FEHLER: LiteLLM antwortet nach 120s nicht."; \
	echo "        Logs ansehen mit:  docker compose logs litellm"; \
	exit 1

# Nach dem ersten "make up" — und erneut, sobald sich die Modellliste in
# config.yaml ändert.
#
# Hintergrund: /v1/models liefert alles, was der verwendete Schlüssel darf —
# mit dem Master-Key also auch das Bild- und das Embedding-Modell, die dann
# im Chat-Modellwähler von Open WebUI auftauchen. LiteLLM kennt kein "aus der
# Liste ausblenden"; gefiltert wird ausschliesslich über die Rechte des
# Schlüssels.
#
# Dieses Ziel legt daher einen Schlüssel an, der genau die Modelle mit
# mode: chat darf. Die Liste wird aus dem laufenden Proxy gelesen, bleibt
# also automatisch in Übereinstimmung mit config.yaml.
#
# WICHTIG — warum der Schlüsselwert stabil bleibt:
# Open WebUI liest OPENAI_API_KEY nur beim allerersten Start und schreibt ihn
# dann in seine eigene Datenbank. Spätere Änderungen an der Umgebung ignoriert
# es. Ein bei jedem Aufruf neu gewürfelter Schlüssel führt deshalb dazu, dass
# Open WebUI sich mit einem inzwischen gelöschten Schlüssel meldet — der
# Modellwähler ist dann leer. LiteLLM erlaubt es, den Schlüsselwert selbst
# vorzugeben; genau das passiert hier: einmal erzeugt, danach wiederverwendet.
bootstrap: wait-litellm
	@MODELS=$$(curl -sS $(LITELLM_URL)/v1/model/info \
		-H "Authorization: Bearer $(LITELLM_MASTER_KEY)" \
		| python3 -c "import sys,json;d=json.load(sys.stdin);print(json.dumps([m['model_name'] for m in d['data'] if (m.get('model_info') or {}).get('mode')=='chat']))"); \
	if [ -z "$$MODELS" ] || [ "$$MODELS" = "[]" ]; then \
		echo "FEHLER: keine Modelle mit mode: chat gefunden."; \
		echo "        Ein Schlüssel ohne Modellliste hätte Zugriff auf alles."; \
		echo "        services/litellm/config.yaml prüfen."; \
		exit 1; \
	fi; \
	echo "==> Chat-Modelle: $$MODELS"; \
	KEY=$$(grep -E '^OPENWEBUI_CHAT_KEY=' .env 2>/dev/null | cut -d= -f2-); \
	if [ -z "$$KEY" ]; then \
		KEY="sk-bit-$$(openssl rand -hex 16)"; \
		echo "==> Neuer Schlüsselwert erzeugt"; \
	else \
		echo "==> Bestehender Schlüsselwert aus .env wiederverwendet"; \
	fi; \
	RESPONSE=$$(curl -sS -X POST $(LITELLM_URL)/key/update \
		-H "Authorization: Bearer $(LITELLM_MASTER_KEY)" \
		-H "Content-Type: application/json" \
		-d "{\"key\":\"$$KEY\",\"key_alias\":\"open-webui-chat\",\"models\":$$MODELS}"); \
	if printf '%s' "$$RESPONSE" | grep -q '"models"'; then \
		echo "==> Bestehender Schlüssel aktualisiert (Ausgaben-Historie bleibt)"; \
	else \
		RESPONSE=$$(curl -sS -X POST $(LITELLM_URL)/key/generate \
			-H "Authorization: Bearer $(LITELLM_MASTER_KEY)" \
			-H "Content-Type: application/json" \
			-d "{\"key\":\"$$KEY\",\"key_alias\":\"open-webui-chat\",\"models\":$$MODELS}"); \
		echo "==> Schlüssel in LiteLLM neu angelegt"; \
	fi; \
	KEY=$$(printf '%s' "$$RESPONSE" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('key') or d.get('token_id') or '')" 2>/dev/null); \
	if [ -z "$$KEY" ]; then \
		KEY=$$(grep -E '^OPENWEBUI_CHAT_KEY=' .env 2>/dev/null | cut -d= -f2-); \
	fi; \
	if [ -z "$$KEY" ]; then \
		echo "FEHLER: kein Schlüssel erhalten. Antwort des Proxys:"; \
		echo "        $$RESPONSE"; \
		exit 1; \
	fi; \
	if grep -q '^OPENWEBUI_CHAT_KEY=' .env; then \
		sed -i.bak "s|^OPENWEBUI_CHAT_KEY=.*|OPENWEBUI_CHAT_KEY=$$KEY|" .env && rm -f .env.bak; \
	else \
		printf '\n# Von "make bootstrap" erzeugt: Schlüssel für Open WebUI,\n# beschränkt auf die Chat-Modelle. Ohne ihn zeigt der Modellwähler\n# zusätzlich das Bild- und das Embedding-Modell.\nOPENWEBUI_CHAT_KEY=%s\n' "$$KEY" >> .env; \
	fi; \
	echo "==> OPENWEBUI_CHAT_KEY in .env gesetzt"; \
	docker compose up -d open-webui; \
	echo "==> Open WebUI neu gestartet — der Modellwähler zeigt jetzt nur die Chat-Modelle."

# Ein Schlüssel pro Teilnehmendem, mit eigenem Budget. Der Provider-Schlüssel
# bleibt dabei im Container — genau der Grund, warum der Proxy existiert.
#   make key NAME=teilnehmer-01 BUDGET=5
key:
	@if [ -z "$(NAME)" ]; then echo "Usage: make key NAME=teilnehmer-01 [BUDGET=5]"; exit 1; fi
	@curl -sS -X POST $(LITELLM_URL)/key/generate \
		-H "Authorization: Bearer $(LITELLM_MASTER_KEY)" \
		-H "Content-Type: application/json" \
		-d '{"key_alias":"$(NAME)","max_budget":$(or $(BUDGET),5),"budget_duration":"30d"}' \
	| python3 -c "import sys,json;d=json.load(sys.stdin);print('Key for $(NAME):');print(' ',d.get('key','FEHLER: '+json.dumps(d)))"

# Ausgaben pro Schlüssel — und zuerst der proxy-weite Deckel.
#
# Der Deckel aus LITELLM_MAX_BUDGET_USD hängt am Proxy, nicht am einzelnen
# Schlüssel. In der Spalte BUDGET steht deshalb "-", solange ein Schlüssel
# kein eigenes Limit hat (das haben nur die von "make key"). Die Zeile GESAMT
# ist die Zahl, bei der der Proxy tatsächlich mit HTTP 400 abriegelt.
spend:
	@curl -sS $(LITELLM_URL)/global/spend \
		-H "Authorization: Bearer $(LITELLM_MASTER_KEY)" \
	| python3 -c "import sys,json;d=json.load(sys.stdin);m=d.get('max_budget');print(f\"GESAMT (Proxy):  {d.get('spend') or 0:.4f} USD von {m if m is not None else '∞'}\");print()"
	@curl -sS $(LITELLM_URL)/key/list?return_full_object=true \
		-H "Authorization: Bearer $(LITELLM_MASTER_KEY)" \
	| python3 -c "import sys,json;ks=json.load(sys.stdin).get('keys',[]);print(f\"{'ALIAS':<24}{'SPEND':>10}{'BUDGET':>10}\");[print(f\"{str(k.get('key_alias') or '-'):<24}{k.get('spend') or 0:>10.4f}{str(k.get('max_budget') or '-'):>10}\") for k in ks if isinstance(k,dict)]"

logs:
	docker compose logs -f

ps:
	docker compose ps

# ---------------------------------------------------------------------------
# Teardown
# ---------------------------------------------------------------------------
clean:
	docker compose down -v
	docker volume ls --filter label=com.docker.compose.project=$(COMPOSE_PROJECT_NAME) -q \
		| xargs -r docker volume rm

clean-py:
	find . -type d -name __pycache__ -exec rm -rf {} +
	find . -type d -name .ruff_cache -exec rm -rf {} +
	find . -type d -name .venv -exec rm -rf {} +
	find . -type d -name __MACOSX -exec rm -rf {} +
	find . -name "*.pyc" -delete
	find . -name ".DS_Store" -delete
