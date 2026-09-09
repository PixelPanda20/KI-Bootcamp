"""Beispielaufruf gegen den LiteLLM-Proxy — der dritte Weg neben Open WebUI und n8n.

Alle drei sprechen dieselbe OpenAI-kompatible Schnittstelle und benutzen
denselben Schlüssel. Der Provider-Schlüssel steckt ausschliesslich im
LiteLLM-Container; hier liegt nur der Virtual Key aus der .env.

    cd training && uv run python example_call.py
    cd training && uv run python example_call.py --stream
"""

from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.request
from pathlib import Path

ENV_FILE = Path(__file__).resolve().parent.parent / ".env"


def read_env() -> dict[str, str]:
    if not ENV_FILE.exists():
        sys.exit(f"{ENV_FILE} fehlt. Zuerst: cp .env.example .env")
    env: dict[str, str] = {}
    for line in ENV_FILE.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, _, v = line.partition("=")
            env[k.strip()] = v.strip()
    return env


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--stream", action="store_true", help="Antwort tokenweise ausgeben")
    parser.add_argument("--prompt", default="Nenne drei Vorteile eines LLM-Gateways. Kurz.")
    args = parser.parse_args()

    env = read_env()
    port = env.get("LITELLM_PORT", "4000")
    model = env.get("CHAT_MODEL", "google/gemini-2.5-flash")

    # Der auf die Chat-Modelle beschränkte Schlüssel aus "make bootstrap".
    # Fällt auf den Master-Key zurück, damit das Skript auch vor dem
    # Bootstrap etwas Sinnvolles tut.
    key = env.get("OPENWEBUI_CHAT_KEY") or env.get("LITELLM_MASTER_KEY")
    if not key:
        sys.exit("Weder OPENWEBUI_CHAT_KEY noch LITELLM_MASTER_KEY in .env gefunden.")

    payload = {
        "model": model,
        "messages": [{"role": "user", "content": args.prompt}],
        # Reasoning-Modelle brauchen ihr Budget zuerst für den Denkschritt.
        # Bei einem knappen Limit kommt eine leere Antwort zurück.
        "max_tokens": 500,
        "stream": args.stream,
    }

    request = urllib.request.Request(
        f"http://127.0.0.1:{port}/v1/chat/completions",
        data=json.dumps(payload).encode(),
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
    )

    print(f"Modell:  {model}")
    print(f"Prompt:  {args.prompt}\n")

    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            if not args.stream:
                body = json.load(response)
                print(body["choices"][0]["message"]["content"])
                usage = body.get("usage", {})
                print(f"\n[{usage.get('total_tokens', '?')} Tokens]")
                return 0

            # Server-Sent Events: eine "data:"-Zeile pro Bruchstück,
            # abgeschlossen durch "data: [DONE]".
            for raw in response:
                line = raw.decode().strip()
                if not line.startswith("data: "):
                    continue
                chunk = line.removeprefix("data: ")
                if chunk == "[DONE]":
                    break
                delta = json.loads(chunk)["choices"][0].get("delta", {})
                print(delta.get("content", ""), end="", flush=True)
            print()
            return 0

    except urllib.error.HTTPError as exc:
        detail = exc.read().decode()[:400]
        if exc.code == 401:
            print(f"401 — Schlüssel ungültig. Nach 'make bootstrap' erneut versuchen.\n{detail}")
        elif exc.code == 400 and "budget" in detail.lower():
            print(f"400 — Budget aufgebraucht. Siehe 'make spend'.\n{detail}")
        else:
            print(f"HTTP {exc.code}\n{detail}")
        return 1
    except urllib.error.URLError as exc:
        print(f"Keine Verbindung zu 127.0.0.1:{port} — läuft der Stack? ('make ps')\n{exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
