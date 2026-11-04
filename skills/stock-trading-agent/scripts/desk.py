#!/usr/bin/env python3
"""Trading desk: the hand-off board between the Manager, Analysts and Trader.

  Manager   set-mandate -> approve / reject / cancel        (decides, never trades)
  Analyst   mandate -> propose                              (finds ideas, never trades)
  Trader    queue -> execute                                (trades only what is approved)

Lifecycle of a proposal:
  proposed --approve--> approved --execute--> executed
           \\-reject--> rejected  \\-(ttl)--> expired   \\-cancel--> cancelled

Proposal kinds:
  entry  buy a new position (bracket order with stop and target)
  stop   raise the protective stop of a position (only ever up)
  exit   close a position (all of it, or --qty shares)

State is an append-only log at $TRADING_DESK or ~/.trading-agent/desk.jsonl, so
several analyst sub-agents can propose at the same time. Executed entries are
logged to journal.py automatically, tagged with the analyst who proposed them.

Examples:
  # Manager: set today's mandate from the regime read
  python3 desk.py set-mandate --regime risk_on --max-exposure 90 \\
      --allowed-setups trend_pullback,breakout,mean_reversion --min-score 60 \\
      --max-new-entries 3 --risk-scale 1.0 --focus "XLK, XLI leaders"

  # Analyst: read the mandate, then propose
  python3 desk.py mandate
  python3 desk.py propose --analyst tech --symbol NVDA --setup breakout \\
      --entry 141.2 --stop 134.9 --target 157.0 --score 81 --confidence high \\
      --expected-r 0.45 --thesis "..." --bull "..." --bear "..." --invalidation "..."
  python3 desk.py propose --kind stop --analyst tech --symbol AAPL --new-stop 191 --reason "+1R: breakeven"

  # Manager: review and decide
  python3 desk.py board
  python3 desk.py approve P-NVDA-... --size 0.75 --notes "Strong RS, but semis crowded"
  python3 desk.py reject  P-TSLA-... --reason "Earnings in 3 days"

  # Trader: execute what is approved
  python3 desk.py queue
  python3 desk.py execute P-NVDA-... [--limit 141.0] [--chase-pct 1.0]
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import random
import string
import sys

import store

SETUPS = ("trend_pullback", "breakout", "mean_reversion")
ACTIVE = ("proposed", "approved")

# Sector of the default universe (references/universe.md), used for the
# concentration check. Analysts can pass --sector for anything else.
SECTORS = {}
for _sector, _names in {
    "tech": "AAPL MSFT NVDA AVGO ORCL CRM ADBE AMD QCOM TXN INTU NOW AMAT MU PANW XLK SMH",
    "communication": "GOOGL GOOG META NFLX TMUS DIS XLC",
    "discretionary": "AMZN TSLA HD MCD LOW BKNG TJX NKE SBUX XLY",
    "staples": "WMT COST PG KO PEP PM XLP",
    "health": "LLY UNH JNJ ABBV MRK TMO ABT ISRG AMGN XLV",
    "financials": "JPM V MA BAC WFC GS MS BLK AXP SPGI XLF",
    "industrials": "GE CAT RTX HON UNP DE LMT BA ETN XLI",
    "energy": "XOM CVX COP EOG SLB XLE",
    "utilities": "NEE SO DUK XLU",
    "real_estate": "PLD AMT XLRE",
    "materials": "LIN SHW FCX XLB",
}.items():
    for _sym in _names.split():
        SECTORS[_sym] = _sector


def path() -> str:
    return store.resolve("TRADING_DESK", "desk.jsonl")


def log(rec: dict) -> dict:
    return store.append_jsonl(path(), rec)


def _now() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def _parse(ts: str) -> dt.datetime:
    return dt.datetime.fromisoformat(ts)


def state() -> dict:
    """Fold the event log into {"mandate": ..., "proposals": {id: proposal}}."""
    mandate, props = None, {}
    for r in store.read_jsonl(path()):
        kind, pid = r.get("type"), r.get("id")
        if kind == "mandate":
            mandate = r
        elif kind == "propose":
            props[pid] = {**r, "status": "proposed", "attempts": []}
        elif pid not in props:
            continue
        elif kind == "approve":
            props[pid].update(status="approved", approval=r)
        elif kind == "reject":
            props[pid].update(status="rejected", rejection=r)
        elif kind == "cancel":
            props[pid].update(status="cancelled", cancellation=r)
        elif kind == "attempt":
            props[pid]["attempts"].append(r)
        elif kind == "execute":
            props[pid].update(status="executed", execution=r)
    now = _now()
    for p in props.values():
        if p["status"] == "approved" and _parse(p["approval"]["expires_at"]) < now:
            p["status"] = "expired"
    if mandate and mandate.get("date") != store.today():
        mandate = {**mandate, "stale": True}
    return {"mandate": mandate, "proposals": props}


def _new_id(symbol: str) -> str:
    stamp = _now().strftime("%Y%m%d%H%M%S")
    tail = "".join(random.choice(string.ascii_lowercase + string.digits) for _ in range(4))
    return f"P-{symbol}-{stamp}-{tail}"


def _sector(p: dict):
    return p.get("sector") or SECTORS.get(p["symbol"])


def _brief(p: dict) -> dict:
    keys = ("id", "kind", "symbol", "status", "analyst", "setup", "entry", "stop", "target",
            "reward_risk", "score", "confidence", "expected_r", "new_stop", "qty", "reason", "ts")
    out = {k: p.get(k) for k in keys if p.get(k) is not None}
    if p.get("approval"):
        out["size"] = p["approval"].get("size")
        out["manager_notes"] = p["approval"].get("notes")
        out["expires_at"] = p["approval"].get("expires_at")
    if p.get("rejection"):
        out["rejected_because"] = p["rejection"].get("reason")
    if p.get("attempts"):
        out["last_attempt"] = p["attempts"][-1].get("reasons")
    if p.get("execution"):
        out["order_id"] = (p["execution"].get("order") or {}).get("id")
    return out


def fail(msg: str, code: int = 2):
    print(json.dumps({"ok": False, "error": msg}, indent=2))
    sys.exit(code)


def done(obj) -> None:
    print(json.dumps(obj, indent=2, default=str))


# ---------------------------------------------------------------- manager


def cmd_set_mandate(a) -> None:
    allowed = [s.strip() for s in a.allowed_setups.split(",") if s.strip()]
    bad = [s for s in allowed if s not in SETUPS]
    if bad:
        fail(f"unknown setups {bad}; choose from {list(SETUPS)}")
    if not 0 < a.risk_scale <= 1:
        fail("--risk-scale must be in (0, 1]: the manager can only reduce risk, never raise it above risk.py")
    done(
        log(
            {
                "type": "mandate",
                "date": store.today(),
                "manager": a.manager,
                "regime": a.regime,
                "max_exposure_pct": a.max_exposure,
                "allowed_setups": allowed,
                "min_score": a.min_score,
                "min_reward_risk": a.min_reward_risk,
                "max_new_entries": a.max_new_entries,
                "max_per_sector": a.max_per_sector,
                "risk_scale": a.risk_scale,
                "focus": a.focus,
                "notes": a.notes,
            }
        )
    )


def _entries_used_today(props: dict) -> int:
    today = store.today()
    return sum(
        1
        for p in props.values()
        if p["kind"] == "entry"
        and p["status"] in ("approved", "executed")
        and str(p["approval"]["ts"]).startswith(today)
    )


def _sector_load(props: dict, positions: list) -> dict:
    load: dict = {}
    for pos in positions:
        sec = SECTORS.get(str(pos.get("symbol", "")).upper())
        if sec:
            load[sec] = load.get(sec, 0) + 1
    for p in props.values():
        if p["kind"] == "entry" and p["status"] == "approved":
            sec = _sector(p)
            if sec:
                load[sec] = load.get(sec, 0) + 1
    return load


def cmd_approve(a) -> None:
    st = state()
    p = st["proposals"].get(a.id)
    if not p:
        fail(f"unknown proposal {a.id}")
    if p["status"] != "proposed":
        fail(f"{a.id} is {p['status']}, only 'proposed' can be approved")
    if not 0 < a.size <= 1:
        fail("--size must be in (0, 1]: the manager can scale a position down, never up")
    precheck = None
    size = a.size
    if p["kind"] == "entry":
        m = st["mandate"]
        if not m or m.get("stale"):
            fail("no mandate for today: run set-mandate first (read the regime, then decide)")
        if p["setup"] not in m["allowed_setups"]:
            fail(f"setup {p['setup']} is not allowed by today's mandate {m['allowed_setups']}")
        used = _entries_used_today(st["proposals"])
        if used >= m["max_new_entries"]:
            fail(f"today's budget of {m['max_new_entries']} new entries is used up ({used})")
        size = min(a.size, m["risk_scale"])
        if not a.no_precheck:
            import alpaca
            import risk

            account, positions = alpaca.get_account(), alpaca.get_positions()
            sec = _sector(p)
            if sec:
                load = _sector_load(st["proposals"], positions).get(sec, 0)
                if load >= m["max_per_sector"]:
                    fail(f"sector '{sec}' already has {load} positions/approvals (max {m['max_per_sector']})")
            verdict = risk.evaluate(
                p["symbol"], p["entry"], p["stop"], p.get("target"), account, positions,
                regime_exposure_pct=m["max_exposure_pct"],
            )
            if verdict["approved"] and size < 1:
                verdict = risk.evaluate(
                    p["symbol"], p["entry"], p["stop"], p.get("target"), account, positions,
                    requested_qty=int(verdict["qty"] * size), regime_exposure_pct=m["max_exposure_pct"],
                )
            if not verdict["approved"]:
                fail("risk pre-check failed: " + "; ".join(verdict["reasons"]))
            precheck = {k: verdict[k] for k in ("qty", "risk_dollars", "position_pct_of_equity", "exposure_after_pct")}
    expires = _now() + dt.timedelta(hours=a.ttl_hours)
    rec = log(
        {
            "type": "approve",
            "id": a.id,
            "manager": a.manager,
            "size": size,
            "notes": a.notes,
            "expires_at": expires.isoformat(timespec="seconds"),
            "precheck": precheck,
        }
    )
    done({"ok": True, "approved": a.id, "size": size, "expires_at": rec["expires_at"], "precheck": precheck})


def cmd_reject(a) -> None:
    p = state()["proposals"].get(a.id)
    if not p:
        fail(f"unknown proposal {a.id}")
    if p["status"] != "proposed":
        fail(f"{a.id} is {p['status']}")
    log({"type": "reject", "id": a.id, "manager": a.manager, "reason": a.reason})
    done({"ok": True, "rejected": a.id})


def cmd_cancel(a) -> None:
    p = state()["proposals"].get(a.id)
    if not p:
        fail(f"unknown proposal {a.id}")
    if p["status"] not in ACTIVE:
        fail(f"{a.id} is {p['status']}")
    log({"type": "cancel", "id": a.id, "by": a.by, "reason": a.reason})
    done({"ok": True, "cancelled": a.id})


# ---------------------------------------------------------------- analyst


def cmd_mandate(a) -> None:
    m = state()["mandate"]
    done(m or {"error": "no mandate yet: the manager must run set-mandate"})


def cmd_propose(a) -> None:
    sym = a.symbol.upper()
    st = state()
    m = st["mandate"]
    for p in st["proposals"].values():
        if p["symbol"] == sym and p["kind"] == a.kind and p["status"] in ACTIVE:
            fail(f"{p['id']} for {sym} ({a.kind}) is already {p['status']}; do not duplicate")
    rec = {"type": "propose", "id": _new_id(sym), "kind": a.kind, "symbol": sym, "analyst": a.analyst}
    warnings = []
    if a.kind == "entry":
        missing = [f for f in ("setup", "entry", "stop", "target", "score", "confidence", "thesis", "bull", "bear", "invalidation")
                   if getattr(a, f) in (None, "")]
        if missing:
            fail("entry proposals need: " + ", ".join("--" + f for f in missing))
        if a.setup not in SETUPS:
            fail(f"unknown setup {a.setup}; choose from {list(SETUPS)}")
        if not a.stop < a.entry < a.target:
            fail("need stop < entry < target (long only)")
        rr = (a.target - a.entry) / (a.entry - a.stop)
        if m and not m.get("stale"):
            if a.setup not in m["allowed_setups"]:
                fail(f"mandate does not allow {a.setup} today (allowed: {m['allowed_setups']})")
            if a.score < m["min_score"]:
                fail(f"score {a.score} is below the mandate minimum {m['min_score']}")
            if rr < m.get("min_reward_risk", 2.0):
                fail(f"reward/risk {rr:.2f} is below the mandate minimum {m.get('min_reward_risk', 2.0)}")
        else:
            warnings.append("no mandate for today; the manager will not approve entries until one is set")
        if a.expected_r is None:
            warnings.append("no --expected-r: back the idea with backtest.py evidence")
        rec.update(
            setup=a.setup, entry=a.entry, stop=a.stop, target=a.target, reward_risk=round(rr, 2),
            score=a.score, confidence=a.confidence, expected_r=a.expected_r, win_rate=a.win_rate,
            sector=a.sector or SECTORS.get(sym), catalysts=a.catalysts, thesis=a.thesis, bull=a.bull,
            bear=a.bear, invalidation=a.invalidation,
        )
    elif a.kind == "stop":
        if a.new_stop is None or not a.reason:
            fail("stop proposals need --new-stop and --reason")
        rec.update(new_stop=a.new_stop, reason=a.reason)
    else:
        if not a.reason:
            fail("exit proposals need --reason")
        rec.update(qty=a.qty, reason=a.reason)
    rec = log({k: v for k, v in rec.items() if v is not None})
    done({"ok": True, "id": rec["id"], "warnings": warnings})


# ---------------------------------------------------------------- trader


def cmd_execute(a) -> None:
    st = state()
    p = st["proposals"].get(a.id)
    if not p:
        fail(f"unknown proposal {a.id}")
    if p["status"] != "approved":
        fail(f"{a.id} is {p['status']}: the trader only executes manager-approved proposals")
    import alpaca

    if p["kind"] == "entry":
        m = st["mandate"] or {}
        max_entry = round(p["entry"] * (1 + a.chase_pct / 100), 2)
        if a.limit is not None and a.limit > max_entry:
            fail(f"limit {a.limit} is above the max entry {max_entry} (proposal {p['entry']} + {a.chase_pct}%)")
        res = alpaca.submit_entry(
            p["symbol"], p["stop"], p.get("target"), limit=a.limit, tif=a.tif,
            max_exposure=m.get("max_exposure_pct"), size_fraction=p["approval"]["size"], max_entry=max_entry,
        )
        if not res["submitted"]:
            log({"type": "attempt", "id": a.id, "trader": a.trader, "reasons": res["risk"].get("reasons")})
            print(json.dumps({"ok": False, "id": a.id, "reasons": res["risk"].get("reasons")}, indent=2))
            sys.exit(2)
        import journal

        order = res["order"]
        trade = journal.open_trade(
            symbol=p["symbol"], setup=p["setup"], entry=res["risk"]["entry"], stop=p["stop"],
            target=p.get("target"), qty=res["risk"]["qty"], score=p.get("score"),
            confidence=p.get("confidence"), regime=m.get("regime"), thesis=p["thesis"],
            invalidation=p["invalidation"], order_id=order.get("id"), analyst=p.get("analyst"),
            proposal_id=p["id"],
        )
        log({"type": "execute", "id": a.id, "trader": a.trader, "order": order, "journal_id": trade["id"]})
        done({"ok": True, "id": a.id, "order": order, "risk": {k: res["risk"].get(k) for k in ("qty", "risk_dollars", "position_pct_of_equity")}, "journal_id": trade["id"]})
    elif p["kind"] == "stop":
        res = alpaca.raise_stop(p["symbol"], p["new_stop"])
        if not res["ok"]:
            log({"type": "attempt", "id": a.id, "trader": a.trader, "reasons": [res["reason"]]})
            fail(res["reason"])
        import journal

        t = journal.find_open_trade(p["symbol"])
        if t:
            journal.append({"type": "note", "id": t["id"], "text": f"stop raised to {p['new_stop']}: {p['reason']}"})
        log({"type": "execute", "id": a.id, "trader": a.trader, "order": res})
        done({"ok": True, "id": a.id, "result": res})
    else:
        res = alpaca.close_position(p["symbol"], p.get("qty"))
        log({"type": "execute", "id": a.id, "trader": a.trader, "order": res})
        done({
            "ok": True, "id": a.id, "order": res,
            "next": "after the fill, record it: journal.py close --id <trade id> --exit <fill price> --reason ...",
        })


def cmd_queue(a) -> None:
    props = state()["proposals"].values()
    done([_brief(p) for p in props if p["status"] == "approved"])


# ---------------------------------------------------------------- shared views


def cmd_list(a) -> None:
    props = list(state()["proposals"].values())
    today = store.today()
    if not a.all:
        props = [p for p in props if str(p["ts"]).startswith(today) or p["status"] in ACTIVE]
    if a.status:
        props = [p for p in props if p["status"] == a.status]
    if a.kind:
        props = [p for p in props if p["kind"] == a.kind]
    done([_brief(p) for p in props])


def cmd_show(a) -> None:
    p = state()["proposals"].get(a.id)
    done(p or {"error": f"unknown proposal {a.id}"})


def cmd_board(a) -> None:
    st = state()
    props = list(st["proposals"].values())
    today = store.today()
    todays = [p for p in props if str(p["ts"]).startswith(today) or p["status"] in ACTIVE]
    by_status: dict = {}
    for p in todays:
        by_status.setdefault(p["status"], []).append(_brief(p))
    m = st["mandate"]
    done(
        {
            "mandate": m,
            "entries_approved_today": _entries_used_today(st["proposals"]),
            "entry_budget": m.get("max_new_entries") if m else None,
            "awaiting_manager": by_status.get("proposed", []),
            "awaiting_trader": by_status.get("approved", []),
            "done_today": {k: v for k, v in by_status.items() if k not in ACTIVE},
        }
    )


def main(argv=None) -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("set-mandate", help="MANAGER: today's rules of engagement")
    p.add_argument("--regime", required=True, choices=["risk_on", "neutral", "risk_off"])
    p.add_argument("--max-exposure", type=float, required=True, help="gross exposure cap %%")
    p.add_argument("--allowed-setups", required=True, help="comma-separated")
    p.add_argument("--min-score", type=float, default=60)
    p.add_argument("--min-reward-risk", type=float, default=2.0)
    p.add_argument("--max-new-entries", type=int, default=3)
    p.add_argument("--max-per-sector", type=int, default=3)
    p.add_argument("--risk-scale", type=float, default=1.0, help="0-1, scales every position down")
    p.add_argument("--focus", help="where analysts should hunt, e.g. leading sectors")
    p.add_argument("--notes")
    p.add_argument("--manager", default="manager")

    p = sub.add_parser("approve", help="MANAGER")
    p.add_argument("id")
    p.add_argument("--size", type=float, default=1.0, help="fraction of the risk-approved size (conviction)")
    p.add_argument("--ttl-hours", type=float, default=6.0)
    p.add_argument("--notes", required=True, help="why you approve; what you challenged")
    p.add_argument("--no-precheck", action="store_true", help="skip the live account/sector pre-check")
    p.add_argument("--manager", default="manager")

    p = sub.add_parser("reject", help="MANAGER")
    p.add_argument("id")
    p.add_argument("--reason", required=True)
    p.add_argument("--manager", default="manager")

    p = sub.add_parser("cancel", help="withdraw a proposed/approved item")
    p.add_argument("id")
    p.add_argument("--reason", required=True)
    p.add_argument("--by", default="manager")

    sub.add_parser("mandate", help="ANALYST: read today's mandate")

    p = sub.add_parser("propose", help="ANALYST")
    p.add_argument("--kind", default="entry", choices=["entry", "stop", "exit"])
    p.add_argument("--analyst", required=True, help="name of the proposing analyst")
    p.add_argument("--symbol", required=True)
    p.add_argument("--setup")
    p.add_argument("--entry", type=float)
    p.add_argument("--stop", type=float)
    p.add_argument("--target", type=float)
    p.add_argument("--score", type=float)
    p.add_argument("--confidence", choices=["low", "medium", "high"])
    p.add_argument("--expected-r", type=float, help="backtested expectancy of this setup (R per trade)")
    p.add_argument("--win-rate", type=float, help="backtested win rate %%")
    p.add_argument("--sector")
    p.add_argument("--catalysts", help="earnings date, news checked")
    p.add_argument("--thesis")
    p.add_argument("--bull")
    p.add_argument("--bear")
    p.add_argument("--invalidation")
    p.add_argument("--new-stop", type=float, help="kind=stop")
    p.add_argument("--qty", type=float, help="kind=exit: partial exit")
    p.add_argument("--reason", help="kind=stop/exit")

    p = sub.add_parser("execute", help="TRADER")
    p.add_argument("id")
    p.add_argument("--limit", type=float, help="limit price; omit for market")
    p.add_argument("--chase-pct", type=float, default=1.0, help="max %% above the proposed entry")
    p.add_argument("--tif", default="day", choices=["day", "gtc"])
    p.add_argument("--trader", default="trader")

    sub.add_parser("queue", help="TRADER: approved proposals waiting for execution")
    p = sub.add_parser("list")
    p.add_argument("--status")
    p.add_argument("--kind", choices=["entry", "stop", "exit"])
    p.add_argument("--all", action="store_true", help="include past days")
    p = sub.add_parser("show")
    p.add_argument("id")
    sub.add_parser("board", help="MANAGER: everything on the desk today")

    a = ap.parse_args(argv)
    {
        "set-mandate": cmd_set_mandate,
        "approve": cmd_approve,
        "reject": cmd_reject,
        "cancel": cmd_cancel,
        "mandate": cmd_mandate,
        "propose": cmd_propose,
        "execute": cmd_execute,
        "queue": cmd_queue,
        "list": cmd_list,
        "show": cmd_show,
        "board": cmd_board,
    }[a.cmd](a)


if __name__ == "__main__":
    main()
