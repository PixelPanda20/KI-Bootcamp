#!/usr/bin/env python3
"""Arbeitsplatz-Check für Lernende.

Prüft aus Sicht der/des Lernenden, ob die Umgebung bereit ist: Python-Paket,
laufender Stack, Provider-Zugang, Datenbank. Bewusst nur mit der
Standardbibliothek, damit das Skript auch dann noch etwas Sinnvolles sagt,
wenn die virtuelle Umgebung unvollständig ist.

Angenommen wird, dass der Stack unter /opt/bit-bootcamp liegt; bei abweichender
Ablage die Pfade in den Hinweisen unten entsprechend lesen. Die .env sucht das
Skript ohnehin selbst (siehe ENV_CANDIDATES).

    cd /opt/bit-bootcamp/training
    uv run python check_setup.py

Geprüft wird nur, was für die Übungen gebraucht wird — nicht die Abnahme der
VM selbst (Container-Namen, Berechtigungen, Härtung).
"""

from __future__ import annotations

import json
import os
import socket
import sys
import urllib.error
import urllib.request
from pathlib import Path
from urllib.parse import quote

GREEN, YELLOW, RED, GREY, BOLD, RESET = (
    "\033[32m", "\033[33m", "\033[31m", "\033[90m", "\033[1m", "\033[0m"
)

HERE = Path(__file__).resolve().parent
# .env liegt beim Stack, nicht im Arbeitsverzeichnis der Lernenden.
ENV_CANDIDATES = [HERE / ".env", HERE.parent / ".env", Path("/opt/bit-bootcamp/.env")]

problems: list[str] = []


def ok(msg: str, detail: str = "") -> None:
    print(f"  {GREEN}[OK]{RESET}   {msg}" + (f" {GREY}{detail}{RESET}" if detail else ""))


def warn(msg: str, hint: str = "") -> None:
    print(f"  {YELLOW}[WARN]{RESET} {msg}" + (f" {GREY}{hint}{RESET}" if hint else ""))


def fail(msg: str, hint: str = "") -> None:
    problems.append(msg)
    print(f"  {RED}[FAIL]{RESET} {msg}" + (f" {GREY}{hint}{RESET}" if hint else ""))


def section(title: str) -> None:
    print(f"\n{BOLD}{title}{RESET}")


def load_env() -> dict[str, str]:
    for path in ENV_CANDIDATES:
        if not path.exists():
            continue
        values: dict[str, str] = {}
        for raw in path.read_text(encoding="utf-8").splitlines():
            line = raw.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, val = line.partition("=")
            values[key.strip()] = val.strip().strip("'\"")
        values["_source"] = str(path)
        return values
    return {}


def http(url: str, *, headers: dict | None = None, payload: dict | None = None,
         timeout: int = 30) -> tuple[int, object]:
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(url, data=data, headers=headers or {},
                                 method="POST" if data else "GET")
    if data:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = resp.read().decode("utf-8", "replace")
            try:
                return resp.status, json.loads(body)
            except json.JSONDecodeError:
                return resp.status, body
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read().decode("utf-8", "replace")[:300]
    except Exception as exc:  # noqa: BLE001
        return 0, str(exc)


# ---------------------------------------------------------------------------

def check_python() -> None:
    section("1. Python-Umgebung")
    major, minor = sys.version_info[:2]
    if (major, minor) == (3, 12):
        ok(f"Python {major}.{minor}", sys.executable)
    else:
        fail(f"Python 3.12 erwartet, gefunden {major}.{minor}", sys.executable)

    if sys.prefix == sys.base_prefix:
        warn("Kein Virtualenv aktiv", "uv run python check_setup.py verwenden")
    else:
        ok("Virtualenv aktiv", sys.prefix)

    required = [
        "openai", "httpx", "dotenv", "pydantic", "langchain", "langchain_openai",
        "langgraph", "fastmcp", "mcp", "fastapi", "chromadb", "psycopg",
        "pgvector", "rich", "ipykernel",
    ]
    missing = [m for m in required if not _importable(m)]
    if missing:
        fail(f"{len(missing)} Pakete fehlen", ", ".join(missing) + "  →  uv sync")
    else:
        ok(f"Alle {len(required)} Kernpakete importierbar")


def _importable(module: str) -> bool:
    try:
        __import__(module)
        return True
    except Exception:  # noqa: BLE001 — kaputtes Paket zählt auch als fehlend
        return False


def _port(env: dict[str, str], key: str, default: int) -> int:
    """Host-Port aus der Umgebung lesen.

    load_env() liefert nur ein dict und setzt os.environ nicht, deshalb wird
    beides geprüft: eine echte Umgebungsvariable hat Vorrang vor der .env.
    """
    raw = os.getenv(key) or env.get(key) or str(default)
    try:
        return int(raw)
    except ValueError:
        return default


def check_stack(env: dict[str, str]) -> None:
    section("2. Kurs-Stack")
    # Open WebUI und n8n hängen hinter Caddy und sind nur über ihren Namen
    # erreichbar. LiteLLM und Datenbank haben weiterhin eigene Ports.
    http_port = _port(env, "HTTP_PORT", 80)
    targets = (
        ("Open WebUI", "bit-chat", http_port),
        ("n8n", "bit-n8n", http_port),
        ("LiteLLM", "127.0.0.1", _port(env, "LITELLM_PORT", 4000)),
        ("PostgreSQL", "127.0.0.1", _port(env, "POSTGRES_PORT", 5432)),
    )
    for name, host, port in targets:
        try:
            with socket.socket() as sock:
                sock.settimeout(3)
                reachable = sock.connect_ex((host, port)) == 0
        except OSError:
            # Unbekannter Name -> die /etc/hosts-Zeile fehlt. Das ist ein
            # anderes Problem als "Stack läuft nicht", also eigener Hinweis.
            fail(f"{name}: Name '{host}' nicht auflösbar",
                 "cd /opt/bit-bootcamp && make hosts")
            continue
        if reachable:
            ok(f"{name} erreichbar", f"{host}:{port}")
        else:
            fail(f"{name} nicht erreichbar ({host}:{port})",
                 "cd /opt/bit-bootcamp && docker compose up -d")


def check_database(env: dict[str, str]) -> None:
    section("3. Vector Store")
    try:
        import psycopg
    except ImportError:
        fail("psycopg nicht installiert", "uv sync")
        return

    # Zugangsdaten aus der .env, nicht fest verdrahtet: ändert der Betrieb
    # POSTGRES_USER/POSTGRES_PASSWORD, meldete ein fester Wert hier sonst
    # "Datenbank nicht erreichbar", obwohl der Stack in Ordnung ist.
    user = os.getenv("POSTGRES_USER") or env.get("POSTGRES_USER") or "n8n"
    password = os.getenv("POSTGRES_PASSWORD") or env.get("POSTGRES_PASSWORD") or "n8n"
    dsn = os.getenv(
        "BOOTCAMP_DATABASE_URL",
        f"postgresql://{quote(user, safe='')}:{quote(password, safe='')}"
        f"@127.0.0.1:{_port(env, 'POSTGRES_PORT', 5432)}/bootcamp",
    )
    try:
        with psycopg.connect(dsn, connect_timeout=5) as conn:
            row = conn.execute(
                "SELECT extname FROM pg_extension WHERE extname = 'vector'"
            ).fetchone()
        if row:
            ok("Datenbank 'bootcamp' bereit, pgvector aktiv")
        else:
            fail("pgvector-Extension fehlt in 'bootcamp'",
                 "docker compose down -v && docker compose up -d")
    except Exception as exc:  # noqa: BLE001
        fail("Datenbank nicht erreichbar", f"{str(exc)[:120]}")


def check_provider(env: dict[str, str]) -> None:
    section("4. Modell-Provider")
    if not env:
        fail(".env nicht gefunden", " oder ".join(str(p) for p in ENV_CANDIDATES))
        return
    ok("Konfiguration gelesen", env.get("_source", ""))

    # Geprüft wird gegen LiteLLM, nicht gegen den Provider. Das ist der Weg,
    # den Open WebUI und n8n auch nehmen — ein Fehler hier trifft also
    # genau das, was die Lernenden benutzen. Der Provider-Schlüssel liegt
    # ohnehin nur im Container.
    key = env.get("OPENWEBUI_CHAT_KEY") or env.get("LITELLM_MASTER_KEY", "")
    base = f"http://127.0.0.1:{_port(env, 'LITELLM_PORT', 4000)}/v1"
    model = env.get("CHAT_MODEL", "")

    if not key:
        fail("LITELLM_MASTER_KEY ist leer", "Wert aus .env.example übernehmen")
        return
    ok("LiteLLM-Schlüssel gesetzt", f"{key[:10]}…{key[-4:]}")
    if not model:
        fail("CHAT_MODEL fehlt")
        return

    headers = {"Authorization": f"Bearer {key}"}

    status, body = http(
        f"{base}/chat/completions", headers=headers,
        payload={"model": model,
                 "messages": [{"role": "user", "content": "Antworte nur mit: OK"}],
                 # Denkende Modelle verbrauchen die ersten Tokens für
                 # reasoning; bei 5 käme content leer zurück.
                 "max_tokens": 300},
        timeout=60,
    )
    if status == 200 and isinstance(body, dict):
        try:
            reply = body["choices"][0]["message"]["content"].strip()
            ok("Chat-Modell antwortet", f'{model} → "{reply[:30]}"')
        except (KeyError, IndexError, TypeError):
            warn("Antwort in unerwartetem Format", str(body)[:100])
    elif status == 400:
        # LiteLLM meldet ein erschöpftes Budget als 400, nicht als 402.
        fail("400 — Budget erschöpft oder Modell nicht erlaubt", str(body)[:150])
    elif status == 401:
        fail("401 — Key ungültig", "Bei der Kursleitung melden")
    elif status == 402:
        fail("402 — Guthaben aufgebraucht", "Bei der Kursleitung melden")
    elif status == 429:
        warn("429 — Rate Limit", "Kurz warten und erneut versuchen")
    elif status == 0:
        fail("Keine Verbindung zu LiteLLM", "docker compose up -d litellm")
    else:
        fail(f"HTTP {status}", str(body)[:150])


def main() -> int:
    print(f"{BOLD}KI-Bootcamp — Arbeitsplatz-Check{RESET}")
    print(f"{GREY}{HERE}{RESET}")

    env = load_env()
    check_python()
    check_stack(env)
    check_database(env)
    check_provider(env)

    print(f"\n{BOLD}{'─' * 60}{RESET}")
    if problems:
        print(f"{RED}{len(problems)} Problem(e){RESET} — bitte der Kursleitung zeigen:\n")
        for item in problems:
            print(f"  {RED}•{RESET} {item}")
        return 1
    print(f"{GREEN}Alles bereit. Viel Erfolg!{RESET}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
