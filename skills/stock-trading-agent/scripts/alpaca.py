#!/usr/bin/env python3
"""Alpaca PAPER-trading and market-data client (stdlib only).

Live trading is deliberately impossible from this script:
  * the trading endpoint is hard-coded to https://paper-api.alpaca.markets
  * APCA_API_BASE_URL pointing anywhere else aborts the program
  * live key IDs (prefix "AK") are refused
  * every new entry passes through risk.py and must carry a stop-loss

Credentials come from APCA_API_KEY_ID / APCA_API_SECRET_KEY
(ALPACA_API_KEY / ALPACA_SECRET_KEY are accepted as aliases).

Examples:
  python3 alpaca.py clock
  python3 alpaca.py account
  python3 alpaca.py positions
  python3 alpaca.py orders --status open --nested
  python3 alpaca.py bars SPY AAPL --days 400 --out bars.json
  python3 alpaca.py snapshot AAPL MSFT
  python3 alpaca.py buy AAPL --stop 182.5 --target 205 [--qty 10] [--limit 190.1] [--max-exposure 50]
  python3 alpaca.py raise-stop AAPL --stop 188   # finds the stop leg; only moves it up
  python3 alpaca.py replace <order_id> --stop 188
  python3 alpaca.py close AAPL [--qty 5]
  python3 alpaca.py cancel <order_id>
  python3 alpaca.py kill            # cancel all orders and flatten all positions
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

PAPER_URL = "https://paper-api.alpaca.markets"
DATA_URL = "https://data.alpaca.markets"


def die(msg: str, code: int = 1) -> None:
    print(json.dumps({"error": msg}), file=sys.stderr)
    sys.exit(code)


def _check_paper_only() -> None:
    override = os.environ.get("APCA_API_BASE_URL", "").strip().rstrip("/")
    if override.endswith("/v2"):
        override = override[: -len("/v2")]
    if override and override != PAPER_URL:
        die(
            f"APCA_API_BASE_URL={override!r} is not the paper endpoint. "
            "This skill only trades on paper; unset it or set it to " + PAPER_URL
        )


def _credentials():
    key = os.environ.get("APCA_API_KEY_ID") or os.environ.get("ALPACA_API_KEY")
    secret = os.environ.get("APCA_API_SECRET_KEY") or os.environ.get("ALPACA_SECRET_KEY")
    if not key or not secret:
        die(
            "Missing credentials. Create a free paper account at https://alpaca.markets, "
            "then export APCA_API_KEY_ID and APCA_API_SECRET_KEY (paper keys start with 'PK')."
        )
    if key.startswith("AK"):
        die("This looks like a LIVE Alpaca key (prefix 'AK'). Use paper keys (prefix 'PK').")
    return key, secret


def request(method: str, base: str, path: str, params=None, body=None):
    _check_paper_only()
    key, secret = _credentials()
    url = base + path
    if params:
        clean = {k: v for k, v in params.items() if v is not None}
        if clean:
            url += "?" + urllib.parse.urlencode(clean)
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={
            "APCA-API-KEY-ID": key,
            "APCA-API-SECRET-KEY": secret,
            "Accept": "application/json",
            "Content-Type": "application/json",
            "User-Agent": "stock-trading-agent-skill/1.0",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            raw = resp.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")
        die(f"HTTP {e.code} on {method} {path}: {detail}")
    except urllib.error.URLError as e:
        die(f"Network error on {method} {path}: {e.reason}")


def trading(method: str, path: str, params=None, body=None):
    return request(method, PAPER_URL, path, params, body)


def market_data(path: str, params=None):
    return request("GET", DATA_URL, path, params)


# ---------------------------------------------------------------- read-only


def get_account() -> dict:
    return trading("GET", "/v2/account")


def get_positions() -> list:
    return trading("GET", "/v2/positions")


def get_clock() -> dict:
    return trading("GET", "/v2/clock")


def get_orders(status: str = "open", limit: int = 100, nested: bool = False) -> list:
    return trading(
        "GET",
        "/v2/orders",
        {"status": status, "limit": limit, "nested": "true" if nested else None},
    )


def get_bars(symbols, days: int = 400, timeframe: str = "1Day", feed: str = "iex") -> dict:
    """Return {symbol: [{t,o,h,l,c,v}, ...]} oldest first, following pagination."""
    start = (dt.datetime.now(dt.timezone.utc) - dt.timedelta(days=days)).strftime("%Y-%m-%d")
    out = {s.upper(): [] for s in symbols}
    token = None
    while True:
        page = market_data(
            "/v2/stocks/bars",
            {
                "symbols": ",".join(out.keys()),
                "timeframe": timeframe,
                "start": start,
                "limit": 10000,
                "adjustment": "all",
                "feed": feed,
                "page_token": token,
            },
        )
        for sym, bars in (page.get("bars") or {}).items():
            out.setdefault(sym, []).extend(bars)
        token = page.get("next_page_token")
        if not token:
            break
    return out


def get_snapshots(symbols, feed: str = "iex") -> dict:
    return market_data(
        "/v2/stocks/snapshots", {"symbols": ",".join(s.upper() for s in symbols), "feed": feed}
    )


# ---------------------------------------------------------------- trading


def submit_entry(
    symbol: str,
    stop: float,
    target,
    qty=None,
    limit=None,
    tif: str = "day",
    max_exposure=None,
    size_fraction: float = 1.0,
    max_entry=None,
):
    """Risk-checked long entry with an attached stop-loss (and optional take-profit).

    size_fraction scales the risk-approved quantity down (manager conviction).
    max_entry refuses to buy above that price (no chasing).
    """
    import risk  # local module; imported lazily so read-only commands stay light

    symbol = symbol.upper()
    account = get_account()
    positions = get_positions()
    if limit is not None:
        entry = float(limit)
    else:
        snap = get_snapshots([symbol]).get(symbol) or {}
        trade = snap.get("latestTrade") or {}
        entry = float(trade.get("p") or 0)
        if entry <= 0:
            die(f"Could not get a last price for {symbol}; pass --limit explicitly.")

    if max_entry is not None and entry > float(max_entry):
        return {
            "submitted": False,
            "risk": {
                "approved": False,
                "entry": entry,
                "reasons": [
                    f"price {entry:.2f} is above the max entry {float(max_entry):.2f}: "
                    "do not chase; wait for a pullback or use a limit at or below it"
                ],
            },
        }

    def check(requested):
        return risk.evaluate(
            symbol=symbol,
            entry=entry,
            stop=stop,
            target=target,
            account=account,
            positions=positions,
            requested_qty=requested,
            regime_exposure_pct=max_exposure,
        )

    verdict = check(qty)
    if verdict["approved"] and size_fraction < 1.0:
        verdict = check(max(0, int(verdict["qty"] * max(0.0, size_fraction))))
        verdict["size_fraction"] = size_fraction
    if not verdict["approved"]:
        return {"submitted": False, "risk": verdict}

    body = {
        "symbol": symbol,
        "qty": str(verdict["qty"]),
        "side": "buy",
        "type": "limit" if limit is not None else "market",
        "time_in_force": tif,
        "stop_loss": {"stop_price": f"{stop:.2f}"},
    }
    if limit is not None:
        body["limit_price"] = f"{float(limit):.2f}"
    if target is not None:
        body["order_class"] = "bracket"
        body["take_profit"] = {"limit_price": f"{float(target):.2f}"}
    else:
        body["order_class"] = "oto"
    order = trading("POST", "/v2/orders", body=body)
    return {"submitted": True, "risk": verdict, "order": _order_summary(order)}


def replace_order(order_id: str, stop=None, limit=None, qty=None) -> dict:
    body = {}
    if stop is not None:
        body["stop_price"] = f"{float(stop):.2f}"
    if limit is not None:
        body["limit_price"] = f"{float(limit):.2f}"
    if qty is not None:
        body["qty"] = str(qty)
    if not body:
        die("Nothing to replace: pass --stop, --limit or --qty.")
    return _order_summary(trading("PATCH", f"/v2/orders/{order_id}", body=body))


OPEN_STATUSES = {"new", "accepted", "held", "pending_new", "partially_filled", "pending_replace"}


def find_stop_orders(symbol: str) -> list:
    """Open sell-stop orders protecting ``symbol`` (bracket/OTO legs included)."""
    symbol = symbol.upper()
    seen, found = set(), []
    orders = get_orders("open", 500, nested=False) + get_orders("open", 500, nested=True)
    for o in orders:
        for c in [o] + list(o.get("legs") or []):
            if (
                c.get("id") not in seen
                and str(c.get("symbol", "")).upper() == symbol
                and c.get("side") == "sell"
                and c.get("type") in ("stop", "stop_limit")
                and c.get("status") in OPEN_STATUSES
            ):
                seen.add(c.get("id"))
                found.append(c)
    return found


def raise_stop(symbol: str, new_stop: float) -> dict:
    """Move the protective stop UP. Refuses to lower it or to place it above the price."""
    symbol = symbol.upper()
    pos = next((p for p in get_positions() if str(p.get("symbol")).upper() == symbol), None)
    if pos is None:
        return {"ok": False, "reason": f"no open position in {symbol}"}
    price = float(pos.get("current_price") or 0)
    legs = find_stop_orders(symbol)
    if not legs:
        return {"ok": False, "reason": f"no open stop order found for {symbol}: the position may be UNPROTECTED"}
    if price and new_stop >= price:
        return {"ok": False, "reason": f"new stop {new_stop} is not below the current price {price}; to exit, close the position"}
    highest = max(float(leg.get("stop_price") or 0) for leg in legs)
    if new_stop <= highest:
        return {"ok": False, "reason": f"stops only move up: current stop is {highest}, requested {new_stop}"}
    results = []
    for leg in legs:
        current = float(leg.get("stop_price") or 0)
        results.append({"from": current, "to": new_stop, "order": replace_order(leg["id"], stop=new_stop)})
    return {"ok": True, "symbol": symbol, "price": price, "replaced": results}


def close_position(symbol: str, qty=None) -> dict:
    params = {"qty": str(qty)} if qty is not None else None
    return trading("DELETE", f"/v2/positions/{symbol.upper()}", params)


def cancel_order(order_id: str) -> dict:
    trading("DELETE", f"/v2/orders/{order_id}")
    return {"cancelled": order_id}


def kill_switch() -> dict:
    cancelled = trading("DELETE", "/v2/orders")
    closed = trading("DELETE", "/v2/positions", {"cancel_orders": "true"})
    return {"cancelled_orders": cancelled, "closed_positions": closed}


# ---------------------------------------------------------------- formatting


def _f(x):
    try:
        return round(float(x), 4)
    except (TypeError, ValueError):
        return x


def _account_summary(a: dict) -> dict:
    equity, last = _f(a.get("equity")), _f(a.get("last_equity"))
    day_pl = round(equity - last, 2) if isinstance(equity, float) and isinstance(last, float) else None
    return {
        "status": a.get("status"),
        "equity": equity,
        "last_equity": last,
        "day_pl": day_pl,
        "day_pl_pct": round(day_pl / last * 100, 3) if day_pl is not None and last else None,
        "cash": _f(a.get("cash")),
        "buying_power": _f(a.get("buying_power")),
        "long_market_value": _f(a.get("long_market_value")),
        "daytrade_count": a.get("daytrade_count"),
        "pattern_day_trader": a.get("pattern_day_trader"),
        "trading_blocked": a.get("trading_blocked"),
    }


def _position_summary(p: dict) -> dict:
    return {
        "symbol": p.get("symbol"),
        "qty": _f(p.get("qty")),
        "avg_entry": _f(p.get("avg_entry_price")),
        "price": _f(p.get("current_price")),
        "market_value": _f(p.get("market_value")),
        "unrealized_pl": _f(p.get("unrealized_pl")),
        "unrealized_pl_pct": round(_f(p.get("unrealized_plpc")) * 100, 2)
        if isinstance(_f(p.get("unrealized_plpc")), float)
        else None,
        "change_today_pct": round(_f(p.get("change_today")) * 100, 2)
        if isinstance(_f(p.get("change_today")), float)
        else None,
    }


def _order_summary(o: dict) -> dict:
    out = {
        k: o.get(k)
        for k in (
            "id",
            "symbol",
            "side",
            "type",
            "order_class",
            "qty",
            "filled_qty",
            "filled_avg_price",
            "limit_price",
            "stop_price",
            "status",
            "submitted_at",
        )
    }
    out = {k: v for k, v in out.items() if v is not None}
    if o.get("legs"):
        out["legs"] = [_order_summary(leg) for leg in o["legs"]]
    return out


def emit(obj) -> None:
    print(json.dumps(obj, indent=2, default=str))


def main(argv=None) -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("clock")
    sub.add_parser("account")
    sub.add_parser("positions")
    p = sub.add_parser("orders")
    p.add_argument("--status", default="open", choices=["open", "closed", "all"])
    p.add_argument("--limit", type=int, default=50)
    p.add_argument("--nested", action="store_true", help="include bracket legs")
    p = sub.add_parser("bars")
    p.add_argument("symbols", nargs="+")
    p.add_argument("--days", type=int, default=400)
    p.add_argument("--timeframe", default="1Day")
    p.add_argument("--feed", default="iex", help="iex (free) or sip (paid)")
    p.add_argument("--out", help="write JSON to this file instead of stdout")
    p = sub.add_parser("snapshot")
    p.add_argument("symbols", nargs="+")
    p.add_argument("--feed", default="iex")
    p = sub.add_parser("buy", help="risk-checked long entry with stop-loss")
    p.add_argument("symbol")
    p.add_argument("--stop", type=float, required=True, help="stop-loss price (required)")
    p.add_argument("--target", type=float, help="take-profit price (makes it a bracket)")
    p.add_argument("--qty", type=int, help="shares; defaults to the risk-sized quantity")
    p.add_argument("--limit", type=float, help="limit price; omit for a market order")
    p.add_argument("--tif", default="day", choices=["day", "gtc"])
    p.add_argument("--max-exposure", type=float, help="regime cap on gross exposure %% (from analyze.py)")
    p = sub.add_parser("replace", help="modify an open order (e.g. trail a stop leg)")
    p.add_argument("order_id")
    p.add_argument("--stop", type=float)
    p.add_argument("--limit", type=float)
    p.add_argument("--qty", type=int)
    p = sub.add_parser("raise-stop", help="move the protective stop of a position up")
    p.add_argument("symbol")
    p.add_argument("--stop", type=float, required=True)
    p = sub.add_parser("close")
    p.add_argument("symbol")
    p.add_argument("--qty", type=float)
    p = sub.add_parser("cancel")
    p.add_argument("order_id")
    sub.add_parser("kill", help="cancel every order and flatten every position")

    a = ap.parse_args(argv)
    if a.cmd == "clock":
        emit(get_clock())
    elif a.cmd == "account":
        emit(_account_summary(get_account()))
    elif a.cmd == "positions":
        emit([_position_summary(p) for p in get_positions()])
    elif a.cmd == "orders":
        emit([_order_summary(o) for o in get_orders(a.status, a.limit, a.nested)])
    elif a.cmd == "bars":
        bars = get_bars(a.symbols, a.days, a.timeframe, a.feed)
        if a.out:
            with open(a.out, "w") as fh:
                json.dump(bars, fh)
            emit({"written": a.out, "counts": {k: len(v) for k, v in bars.items()}})
        else:
            emit(bars)
    elif a.cmd == "snapshot":
        emit(get_snapshots(a.symbols, a.feed))
    elif a.cmd == "buy":
        emit(submit_entry(a.symbol, a.stop, a.target, a.qty, a.limit, a.tif, a.max_exposure))
    elif a.cmd == "replace":
        emit(replace_order(a.order_id, a.stop, a.limit, a.qty))
    elif a.cmd == "raise-stop":
        res = raise_stop(a.symbol, a.stop)
        emit(res)
        if not res["ok"]:
            sys.exit(2)
    elif a.cmd == "close":
        emit(close_position(a.symbol, a.qty))
    elif a.cmd == "cancel":
        emit(cancel_order(a.order_id))
    elif a.cmd == "kill":
        emit(kill_switch())


if __name__ == "__main__":
    main()
