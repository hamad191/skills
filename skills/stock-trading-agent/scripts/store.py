"""Append-only JSONL storage shared by journal.py and desk.py.

Appending one short line per event keeps concurrent writers (for example
several analyst sub-agents proposing at once) from clobbering each other.
"""

from __future__ import annotations

import datetime as dt
import json
import os


def now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")


def today() -> str:
    return dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%d")


def resolve(env_var: str, default_name: str) -> str:
    p = os.environ.get(env_var) or os.path.join(os.path.expanduser("~/.trading-agent"), default_name)
    os.makedirs(os.path.dirname(p) or ".", exist_ok=True)
    return p


def read_jsonl(path: str) -> list:
    if not os.path.exists(path):
        return []
    out = []
    with open(path) as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                out.append(json.loads(line))
            except json.JSONDecodeError:
                continue  # tolerate a torn line rather than losing the whole log
    return out


def append_jsonl(path: str, rec: dict) -> dict:
    rec = {"ts": now(), **rec}
    with open(path, "a") as fh:
        fh.write(json.dumps(rec) + "\n")
    return rec
