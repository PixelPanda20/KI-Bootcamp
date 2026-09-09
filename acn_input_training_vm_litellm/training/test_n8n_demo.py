"""Rauchtest: n8n -> LiteLLM, einmal Chat und einmal Bildgenerierung.

Baut in n8n einen Demo-Ablauf auf, führt ihn aus und prüft das Ergebnis:

    Start -> Bildprompt erzeugen (Chat) -> Bild erzeugen (Bildmodell)

Damit ist in einem Durchlauf belegt, dass die Zugangsdaten stimmen, dass n8n
den Proxy erreicht und dass beide Modellarten funktionieren.

    cd training && uv run python test_n8n_demo.py

Der Ablauf bleibt danach in n8n stehen und kann dort angesehen werden.

Warum ein eigener Schlüssel: der Schlüssel aus "make bootstrap" darf nur die
Chat-Modelle, damit das Bildmodell nicht im Modellwähler von Open WebUI
auftaucht. Für die Bildgenerierung in n8n reicht er deshalb nicht.
"""

from __future__ import annotations

import json
import os
import sys
import time
import urllib.error
import urllib.request
from http.cookiejar import CookieJar
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ENV_FILE = ROOT / ".env"

N8N_EMAIL = os.getenv("N8N_DEMO_EMAIL", "trainer@bit.local")
N8N_PASSWORD = os.getenv("N8N_DEMO_PASSWORD", "BitBootcamp2026")

DEMO_KEY = "sk-bit-n8n-demo-key"  # LiteLLM verlangt mindestens 16 Zeichen
DEMO_KEY_ALIAS = "n8n-demo"
CREDENTIAL_NAME = "LiteLLM Demo (Chat+Bild)"
WORKFLOW_NAME = "LiteLLM Demo — Chat und Bild"

GREEN, RED, GREY, BOLD, RESET = "\033[32m", "\033[31m", "\033[90m", "\033[1m", "\033[0m"

failures = 0


def ok(msg: str, detail: str = "") -> None:
    print(f"  {GREEN}✓{RESET} {msg}" + (f"  {GREY}{detail}{RESET}" if detail else ""))


def bad(msg: str, detail: str = "") -> None:
    global failures
    failures += 1
    print(f"  {RED}✗{RESET} {msg}" + (f"\n      {GREY}{detail}{RESET}" if detail else ""))


def read_env() -> dict[str, str]:
    if not ENV_FILE.exists():
        sys.exit(f"{ENV_FILE} fehlt. Zuerst: cp .env.example .env")
    env = {}
    for line in ENV_FILE.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, _, v = line.partition("=")
            env[k.strip()] = v.strip()
    return env


def request(
    url: str,
    payload: object = None,
    headers: dict[str, str] | None = None,
    opener: urllib.request.OpenerDirector | None = None,
    method: str | None = None,
    timeout: int = 300,
) -> tuple[int, object]:
    data = json.dumps(payload).encode() if payload is not None else None
    hdrs = {"Content-Type": "application/json", **(headers or {})}
    req = urllib.request.Request(url, data=data, headers=hdrs, method=method)
    try:
        with (opener.open(req, timeout=timeout) if opener else urllib.request.urlopen(req, timeout=timeout)) as r:
            body = r.read().decode()
            try:
                return r.status, json.loads(body)
            except json.JSONDecodeError:
                return r.status, body
    except urllib.error.HTTPError as exc:
        body = exc.read().decode()
        try:
            return exc.code, json.loads(body)
        except json.JSONDecodeError:
            return exc.code, body
    except urllib.error.URLError as exc:
        return 0, str(exc)


def unflatten(raw: str) -> object:
    """n8n speichert Ausführungsdaten normalisiert: Zahl-Strings sind Verweise
    in dasselbe Array. Ohne Auflösung ist die Antwort nicht lesbar."""
    arr = json.loads(raw)

    def deref(v: object, seen: tuple[int, ...] = ()) -> object:
        if isinstance(v, str) and v.isdigit() and int(v) < len(arr):
            i = int(v)
            return "<cycle>" if i in seen else deref(arr[i], seen + (i,))
        if isinstance(v, list):
            return [deref(x, seen) for x in v]
        if isinstance(v, dict):
            return {k: deref(x, seen) for k, x in v.items()}
        return v

    return deref(arr[0])


def main() -> int:
    env = read_env()
    litellm = f"http://127.0.0.1:{env.get('LITELLM_PORT', '4000')}"
    master = env.get("LITELLM_MASTER_KEY", "")
    http_port = env.get("HTTP_PORT", "80")
    n8n = "http://bit-n8n" + ("" if http_port == "80" else f":{http_port}")
    chat_model = env.get("CHAT_MODEL", "google/gemini-2.5-flash")
    image_model = env.get("IMAGE_MODEL", "google/gemini-2.5-flash-image")

    print(f"{BOLD}n8n-Rauchtest — Chat und Bild über LiteLLM{RESET}")
    print(f"{GREY}LiteLLM {litellm} · n8n {n8n}{RESET}\n")

    # --- 1) Proxy erreichbar, Schlüssel mit Chat UND Bild ------------------
    print("1) LiteLLM")
    status, _ = request(f"{litellm}/health/liveliness", timeout=10)
    if status != 200:
        bad(f"Proxy nicht erreichbar (HTTP {status})", "Läuft der Stack? 'make ps'")
        return 1
    ok("Proxy erreichbar")

    auth = {"Authorization": f"Bearer {master}"}
    key_spec = {"key": DEMO_KEY, "key_alias": DEMO_KEY_ALIAS,
                "models": [chat_model, image_model]}

    # Erst aktualisieren, nur bei Bedarf neu anlegen. Löschen und neu erzeugen
    # würde den Schlüsselwert zwar erhalten, aber die Ausgaben-Historie
    # zurücksetzen — bei jedem Lauf.
    status, body = request(f"{litellm}/key/update", key_spec, auth, timeout=30)
    if status == 200 and isinstance(body, dict) and body.get("models"):
        ok("Demo-Schlüssel aktualisiert", f"{chat_model} + {image_model}")
    else:
        status, body = request(f"{litellm}/key/generate", key_spec, auth, timeout=30)
        if status != 200 or not isinstance(body, dict) or not body.get("key"):
            bad("Demo-Schlüssel nicht angelegt", json.dumps(body)[:300])
            return 1
        ok("Demo-Schlüssel angelegt", f"{chat_model} + {image_model}")

    # --- 2) An n8n anmelden ------------------------------------------------
    print("\n2) n8n")
    opener = urllib.request.build_opener(
        urllib.request.HTTPCookieProcessor(CookieJar())
    )
    status, body = request(f"{n8n}/rest/settings", opener=opener, timeout=20)
    if status != 200:
        bad(f"n8n nicht erreichbar (HTTP {status})", str(body)[:200])
        return 1
    needs_setup = (body or {}).get("data", {}).get("userManagement", {}).get("showSetupOnFirstLoad")

    account = {"email": N8N_EMAIL, "password": N8N_PASSWORD}
    if needs_setup:
        status, body = request(
            f"{n8n}/rest/owner/setup",
            {**account, "firstName": "BIT", "lastName": "Trainer"},
            opener=opener, timeout=30,
        )
        if status != 200:
            bad("Konto konnte nicht angelegt werden", str(body)[:300])
            return 1
        ok("Konto angelegt", N8N_EMAIL)
    else:
        # n8n erwartet hier emailOrLdapLoginId, nicht email.
        status, body = request(
            f"{n8n}/rest/login",
            {"emailOrLdapLoginId": N8N_EMAIL, "password": N8N_PASSWORD},
            opener=opener, timeout=30,
        )
        if status != 200:
            bad("Anmeldung fehlgeschlagen",
                f"N8N_DEMO_EMAIL / N8N_DEMO_PASSWORD setzen. Antwort: {str(body)[:200]}")
            return 1
        ok("Angemeldet", N8N_EMAIL)

    # --- 3) Zugangsdaten in n8n --------------------------------------------
    # Reste früherer Läufe entfernen, sonst sammeln sich bei jedem Aufruf
    # gleichnamige Abläufe und Zugangsdaten an.
    removed = 0
    for path, name in (("workflows", WORKFLOW_NAME), ("credentials", CREDENTIAL_NAME)):
        _, listing = request(f"{n8n}/rest/{path}", opener=opener, timeout=30)
        for entry in (listing or {}).get("data", []) if isinstance(listing, dict) else []:
            if isinstance(entry, dict) and entry.get("name") == name and entry.get("id"):
                request(f"{n8n}/rest/{path}/{entry['id']}", opener=opener,
                        method="DELETE", timeout=30)
                removed += 1
    if removed:
        ok("Reste früherer Läufe entfernt", f"{removed} Objekt(e)")

    status, body = request(
        f"{n8n}/rest/credentials",
        {"name": CREDENTIAL_NAME, "type": "openAiApi",
         "data": {"apiKey": DEMO_KEY, "url": "http://litellm:4000/v1"}},
        opener=opener, timeout=30,
    )
    cred_id = (body or {}).get("data", {}).get("id") if isinstance(body, dict) else None
    if not cred_id:
        bad("Zugangsdaten nicht angelegt", str(body)[:300])
        return 1
    ok("Zugangsdaten angelegt", f"Base URL http://litellm:4000/v1")

    # --- 4) Ablauf anlegen --------------------------------------------------
    cred_ref = {"openAiApi": {"id": cred_id, "name": CREDENTIAL_NAME}}
    workflow = {
        "name": WORKFLOW_NAME,
        "settings": {"executionOrder": "v1"},
        "nodes": [
            {"parameters": {}, "id": "aaaaaaaa-1111-4111-8111-111111111111",
             "name": "Start", "type": "n8n-nodes-base.manualTrigger",
             "typeVersion": 1, "position": [0, 0]},
            {"parameters": {
                "modelId": {"__rl": True, "value": chat_model, "mode": "id"},
                "messages": {"values": [{
                    "content": "Schreibe einen kurzen englischen Bildprompt "
                               "(max 15 Woerter) fuer ein Bergpanorama. "
                               "Nur der Prompt, kein weiterer Text.",
                    "role": "user"}]},
                "options": {}},
             "id": "bbbbbbbb-2222-4222-8222-222222222222",
             "name": "Bildprompt erzeugen",
             "type": "@n8n/n8n-nodes-langchain.openAi", "typeVersion": 1.8,
             "position": [220, 0], "credentials": cred_ref},
            {"parameters": {
                "resource": "image", "operation": "generate",
                "model": image_model,
                "prompt": "={{ $json.message.content }}",
                "options": {}},
             "id": "cccccccc-3333-4333-8333-333333333333",
             "name": "Bild erzeugen",
             "type": "@n8n/n8n-nodes-langchain.openAi", "typeVersion": 1.8,
             "position": [440, 0], "credentials": cred_ref},
        ],
        "connections": {
            "Start": {"main": [[{"node": "Bildprompt erzeugen", "type": "main", "index": 0}]]},
            "Bildprompt erzeugen": {"main": [[{"node": "Bild erzeugen", "type": "main", "index": 0}]]},
        },
    }
    status, body = request(f"{n8n}/rest/workflows", workflow, opener=opener, timeout=30)
    wf_id = (body or {}).get("data", {}).get("id") if isinstance(body, dict) else None
    if not wf_id:
        bad("Ablauf nicht angelegt", str(body)[:300])
        return 1
    ok("Ablauf angelegt", WORKFLOW_NAME)

    # --- 5) Ausführen -------------------------------------------------------
    print("\n3) Ausführung")
    print(f"  {GREY}… Chat und Bildgenerierung, das dauert einen Moment{RESET}")
    status, body = request(
        f"{n8n}/rest/workflows/{wf_id}/run",
        {"workflowData": {**workflow, "id": wf_id},
         "triggerToStartFrom": {"name": "Start"}},
        opener=opener, timeout=300,
    )
    exec_id = (body or {}).get("data", {}).get("executionId") if isinstance(body, dict) else None
    if not exec_id:
        bad("Ausführung nicht gestartet", str(body)[:300])
        return 1

    deadline = time.time() + 300
    state, execution = "running", {}
    while time.time() < deadline:
        status, body = request(f"{n8n}/rest/executions/{exec_id}", opener=opener, timeout=30)
        execution = (body or {}).get("data", {}) if isinstance(body, dict) else {}
        state = execution.get("status", "")
        if state != "running":
            break
        time.sleep(3)

    if state != "success":
        bad(f"Ausführung endete mit Status '{state}'")
    else:
        ok("Ausführung erfolgreich")

    # --- 6) Ergebnisse prüfen ----------------------------------------------
    print("\n4) Ergebnis")
    raw = execution.get("data")
    if not isinstance(raw, str):
        bad("Keine Ausführungsdaten erhalten")
        return 1 if failures else 0
    run_data = (unflatten(raw) or {}).get("resultData", {}).get("runData", {})

    prompt_text = None
    for run in run_data.get("Bildprompt erzeugen", []):
        if run.get("error"):
            bad("Chat-Node meldet Fehler", json.dumps(run["error"].get("message", ""))[:300])
            continue
        for items in (run.get("data") or {}).get("main", []):
            for item in items or []:
                prompt_text = (item.get("json", {}).get("message") or {}).get("content")
    if prompt_text:
        ok("Chat-Modell hat geantwortet", f'"{prompt_text[:60]}"')
    elif not failures:
        bad("Chat-Node lieferte keinen Text")

    image_seen = False
    for run in run_data.get("Bild erzeugen", []):
        if run.get("error"):
            bad("Bild-Node meldet Fehler", json.dumps(run["error"].get("message", ""))[:300])
            continue
        for items in (run.get("data") or {}).get("main", []):
            for item in items or []:
                for meta in (item.get("binary") or {}).values():
                    mime, size = meta.get("mimeType", ""), meta.get("fileSize", "?")
                    if mime.startswith("image/"):
                        image_seen = True
                        ok("Bild erzeugt", f"{mime}, {size}")
    if not image_seen and not failures:
        bad("Bild-Node lieferte keine Bilddaten")

    print()
    if failures:
        print(f"{RED}{BOLD}{failures} Prüfung(en) fehlgeschlagen.{RESET}")
        print(f"{GREY}Ablauf in n8n ansehen: {n8n}/workflow/{wf_id}{RESET}")
        return 1
    print(f"{GREEN}{BOLD}Alles in Ordnung — n8n erreicht Chat- und Bildmodell.{RESET}")
    print(f"{GREY}Ablauf in n8n ansehen: {n8n}/workflow/{wf_id}{RESET}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
