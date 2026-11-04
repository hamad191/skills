#!/usr/bin/env python3
"""Trading journal: the agent's long-term memory.

Every decision (trade opened, trade closed, trade skipped, lesson learned) is
appended to a JSONL file so later sessions can review what worked.
Location: $TRADING_JOURNAL or ~/.trading-agent/journal.jsonl

Examples:
  python3 journal.py open --symbol AAPL --setup trend_pullback --entry 190.2 \\
      --stop 182.4 --target 209.7 --qty 50 --score 74 --confidence medium \\
      --thesis "Pullback to rising 50DMA, RS leader in XLK" \\
      --invalidation "Daily close below 50DMA" --order-id <alpaca id>
  python3 journal.py note --id AAPL-20261104-1 --text "Stop raised to breakeven at +1R"
  python3 journal.py close --id AAPL-20261104-1 --exit 205.1 --reason target
  python3 journal.py skip --symbol TSLA --reason "Earnings in 2 days"
  python3 journal.py lesson "Breakouts on Fridays faded 4 of 5 times"
  python3 journal.py open-trades
  python3 journal.py review [--last 50]
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import sys


def path() -> str:
    p = os.environ.get("TRADING_JOURNAL") or os.path.expanduser("~/.trading-agent/journal.jsonl")
    os.makedirs(os.path.dirname(p) or ".", exist_ok=True)
    return p


def now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")


def read_all() -> list:
    p = path()
    if not os.path.exists(p):
        return []
    out = []
    with open(p) as fh:
        for line in fh:
            line = line.strip()
            if line:
                try:
                    out.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
    return out


def append(rec: dict) -> dict:
    rec = {"ts": now(), **rec}
    with open(path(), "a") as fh:
        fh.write(json.dumps(rec) + "\n")
    return rec


def trades_state(records: list) -> dict:
    """Fold the event log into {trade_id: trade}."""
    trades = {}
    for r in records:
        kind = r.get("type")
        if kind == "open":
            trades[r["id"]] = {**r, "status": "open", "notes": []}
        elif kind in ("close", "note") and r.get("id") in trades:
            t = trades[r["id"]]
            if kind == "note":
                t["notes"].append(r.get("text"))
            else:
                t.update(
                    status="closed",
                    exit=r["exit"],
                    exit_reason=r.get("reason"),
                    closed_ts=r["ts"],
                    exit_notes=r.get("notes"),
                )
                risk = t["entry"] - t["stop"]
                t["r"] = round((t["exit"] - t["entry"]) / risk, 3) if risk > 0 else None
                t["pl"] = round((t["exit"] - t["entry"]) * (t.get("qty") or 0), 2)
    return trades


def new_id(symbol: str, records: list) -> str:
    day = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%d")
    base = f"{symbol.upper()}-{day}"
    n = sum(1 for r in records if r.get("type") == "open" and str(r.get("id", "")).startswith(base)) + 1
    return f"{base}-{n}"


def _group_stats(trades: list) -> dict:
    rs = [t["r"] for t in trades if t.get("r") is not None]
    if not rs:
        return {"trades": 0}
    wins = [r for r in rs if r > 0]
    losses = [r for r in rs if r <= 0]
    return {
        "trades": len(rs),
        "win_rate_pct": round(len(wins) / len(rs) * 100, 1),
        "expectancy_r": round(sum(rs) / len(rs), 3),
        "avg_win_r": round(sum(wins) / len(wins), 2) if wins else 0,
        "avg_loss_r": round(sum(losses) / len(losses), 2) if losses else 0,
        "profit_factor": round(sum(wins) / -sum(losses), 2) if losses and sum(losses) < 0 else None,
        "total_pl": round(sum(t.get("pl") or 0 for t in trades), 2),
    }


def review(last=None) -> dict:
    records = read_all()
    trades = trades_state(records)
    closed = sorted((t for t in trades.values() if t["status"] == "closed"), key=lambda t: t["closed_ts"])
    if last:
        closed = closed[-last:]
    open_trades = [t for t in trades.values() if t["status"] == "open"]

    def by(key):
        groups = {}
        for t in closed:
            groups.setdefault(str(t.get(key) or "unknown"), []).append(t)
        return {k: _group_stats(v) for k, v in groups.items()}

    streak = 0
    for t in reversed(closed):
        if (t.get("r") or 0) <= 0:
            streak += 1
        else:
            break

    flags = []
    for setup, s in by("setup").items():
        if s["trades"] >= 10 and s["expectancy_r"] < 0:
            flags.append(f"setup '{setup}' has negative expectancy over {s['trades']} trades: pause it and re-backtest")
    if streak >= 3:
        flags.append(f"{streak} losses in a row: halve risk per trade until the next winner and re-check the regime")
    worst = min((t["r"] for t in closed if t.get("r") is not None), default=0)
    if worst < -1.3:
        flags.append(f"worst trade was {worst}R (< -1.3R): stops were gapped through or not honoured")
    hi = by("confidence").get("high", {})
    lo = by("confidence").get("low", {})
    if hi.get("trades", 0) >= 5 and lo.get("trades", 0) >= 5 and hi["expectancy_r"] <= lo["expectancy_r"]:
        flags.append("high-confidence trades are not beating low-confidence ones: confidence is miscalibrated")

    lessons = [r for r in records if r.get("type") == "lesson"][-15:]
    skips = [r for r in records if r.get("type") == "skip"][-10:]
    return {
        "journal": path(),
        "overall": _group_stats(closed),
        "by_setup": by("setup"),
        "by_confidence": by("confidence"),
        "by_regime": by("regime"),
        "losing_streak": streak,
        "flags": flags,
        "open_trades": [
            {k: t.get(k) for k in ("id", "symbol", "setup", "entry", "stop", "target", "qty", "invalidation", "notes", "ts")}
            for t in open_trades
        ],
        "recent_closed": [
            {k: t.get(k) for k in ("id", "symbol", "setup", "entry", "exit", "r", "exit_reason", "closed_ts")}
            for t in closed[-10:]
        ],
        "recent_lessons": [{"ts": r["ts"], "text": r["text"]} for r in lessons],
        "recent_skips": [{"ts": r["ts"], "symbol": r.get("symbol"), "reason": r.get("reason")} for r in skips],
    }


def main(argv=None) -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("open")
    p.add_argument("--symbol", required=True)
    p.add_argument("--setup", required=True)
    p.add_argument("--entry", type=float, required=True)
    p.add_argument("--stop", type=float, required=True)
    p.add_argument("--target", type=float)
    p.add_argument("--qty", type=float)
    p.add_argument("--score", type=float)
    p.add_argument("--confidence", choices=["low", "medium", "high"])
    p.add_argument("--regime")
    p.add_argument("--thesis", required=True)
    p.add_argument("--invalidation", required=True, help="what would prove the thesis wrong")
    p.add_argument("--order-id")
    p = sub.add_parser("close")
    p.add_argument("--id", required=True)
    p.add_argument("--exit", type=float, required=True)
    p.add_argument("--reason", required=True, choices=["target", "stop", "trailing_stop", "time", "thesis_broken", "risk_off", "manual"])
    p.add_argument("--notes")
    p = sub.add_parser("note")
    p.add_argument("--id", required=True)
    p.add_argument("--text", required=True)
    p = sub.add_parser("skip")
    p.add_argument("--symbol", required=True)
    p.add_argument("--reason", required=True)
    p = sub.add_parser("lesson")
    p.add_argument("text")
    sub.add_parser("open-trades")
    p = sub.add_parser("review")
    p.add_argument("--last", type=int)
    a = ap.parse_args(argv)

    records = read_all()
    if a.cmd == "open":
        if a.stop >= a.entry:
            ap.error("stop must be below entry (long only)")
        rec = {k: v for k, v in vars(a).items() if k != "cmd" and v is not None}
        rec["symbol"] = a.symbol.upper()
        out = append({"type": "open", "id": new_id(a.symbol, records), **rec})
    elif a.cmd == "close":
        state = trades_state(records)
        if a.id not in state:
            ap.error(f"unknown trade id {a.id}")
        if state[a.id]["status"] == "closed":
            ap.error(f"trade {a.id} is already closed")
        append({"type": "close", "id": a.id, "exit": a.exit, "reason": a.reason, "notes": a.notes})
        out = trades_state(read_all())[a.id]
    elif a.cmd == "note":
        if a.id not in trades_state(records):
            ap.error(f"unknown trade id {a.id}")
        out = append({"type": "note", "id": a.id, "text": a.text})
    elif a.cmd == "skip":
        out = append({"type": "skip", "symbol": a.symbol.upper(), "reason": a.reason})
    elif a.cmd == "lesson":
        out = append({"type": "lesson", "text": a.text})
    elif a.cmd == "open-trades":
        out = [t for t in trades_state(records).values() if t["status"] == "open"]
    else:
        out = review(a.last)
    print(json.dumps(out, indent=2))


if __name__ == "__main__":
    sys.exit(main())
