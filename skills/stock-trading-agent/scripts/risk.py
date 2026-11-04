#!/usr/bin/env python3
"""Position sizing and pre-trade risk checks.

The limits below are hard rules: alpaca.py refuses any entry this module does
not approve. Override them with a JSON file passed via TRADING_RISK_CONFIG
(only keys present in DEFAULTS are honoured); you can make them stricter, but
values looser than the HARD_CAPS are clamped.

Examples:
  # live account data (needs paper API keys)
  python3 risk.py --symbol AAPL --entry 190 --stop 182 --target 210
  # offline what-if
  python3 risk.py --symbol AAPL --entry 190 --stop 182 --target 210 --equity 100000
  python3 risk.py --show-limits
"""

from __future__ import annotations

import argparse
import json
import math
import os
import sys

DEFAULTS = {
    "risk_per_trade_pct": 1.0,  # equity lost if the stop is hit
    "max_position_pct": 15.0,  # max size of one position vs equity
    "max_gross_exposure_pct": 90.0,  # total long market value vs equity
    "max_open_positions": 8,
    "max_daily_loss_pct": 3.0,  # halt new entries once down this much today
    "min_reward_risk": 2.0,  # (target - entry) / (entry - stop)
    "min_price": 5.0,  # no penny stocks
    "max_stop_distance_pct": 12.0,  # stops wider than this mean the setup is too loose
    "min_stop_distance_pct": 0.5,  # tighter than this gets shaken out by noise
}

# Looser values than these are clamped, whatever the config file says.
HARD_CAPS = {
    "risk_per_trade_pct": ("max", 2.0),
    "max_position_pct": ("max", 25.0),
    "max_gross_exposure_pct": ("max", 100.0),  # never use margin
    "max_open_positions": ("max", 20),
    "max_daily_loss_pct": ("max", 5.0),
    "min_reward_risk": ("min", 1.0),
    "min_price": ("min", 1.0),
}


def load_limits() -> dict:
    limits = dict(DEFAULTS)
    path = os.environ.get("TRADING_RISK_CONFIG")
    if path and os.path.exists(path):
        with open(path) as fh:
            user = json.load(fh)
        for k, v in user.items():
            if k in limits and isinstance(v, (int, float)):
                limits[k] = v
    for k, (kind, cap) in HARD_CAPS.items():
        limits[k] = min(limits[k], cap) if kind == "max" else max(limits[k], cap)
    return limits


def _num(x, default=0.0) -> float:
    try:
        return float(x)
    except (TypeError, ValueError):
        return default


def evaluate(
    symbol: str,
    entry: float,
    stop: float,
    target=None,
    account=None,
    positions=None,
    requested_qty=None,
    regime_exposure_pct=None,
    limits=None,
) -> dict:
    """Return {approved, qty, reasons, warnings, ...} for a long entry."""
    limits = limits or load_limits()
    account = account or {}
    positions = positions or []
    reasons, warnings = [], []
    symbol = symbol.upper()

    equity = _num(account.get("equity"))
    last_equity = _num(account.get("last_equity"), equity)
    buying_power = _num(account.get("buying_power"), equity)
    # Never size off margin: cash-equivalent capacity is capped at equity.
    capacity = min(buying_power, equity)

    if account.get("trading_blocked") or account.get("account_blocked"):
        reasons.append("account is blocked from trading")
    if equity <= 0:
        reasons.append("equity is zero or unknown")
    if entry <= 0 or stop <= 0:
        reasons.append("entry and stop must be positive")
    if stop >= entry:
        reasons.append("stop must be below entry for a long position")
    if entry < limits["min_price"]:
        reasons.append(f"price {entry} below minimum {limits['min_price']}")

    risk_per_share = entry - stop
    stop_pct = risk_per_share / entry * 100 if entry > 0 else 0.0
    if risk_per_share > 0:
        if stop_pct > limits["max_stop_distance_pct"]:
            reasons.append(
                f"stop is {stop_pct:.1f}% away (> {limits['max_stop_distance_pct']}%): setup too loose"
            )
        if stop_pct < limits["min_stop_distance_pct"]:
            reasons.append(
                f"stop is only {stop_pct:.2f}% away (< {limits['min_stop_distance_pct']}%): inside noise"
            )

    rr = None
    if target is not None and risk_per_share > 0:
        rr = (float(target) - entry) / risk_per_share
        if rr < limits["min_reward_risk"]:
            reasons.append(f"reward/risk {rr:.2f} below minimum {limits['min_reward_risk']}")
    elif target is None:
        warnings.append("no take-profit set; manage the exit with the trailing-stop rules")

    day_pl_pct = (equity - last_equity) / last_equity * 100 if last_equity > 0 else 0.0
    if day_pl_pct <= -limits["max_daily_loss_pct"]:
        reasons.append(
            f"daily loss {day_pl_pct:.2f}% hit the {limits['max_daily_loss_pct']}% halt: no new entries today"
        )

    held = {str(p.get("symbol", "")).upper(): p for p in positions}
    if symbol in held:
        reasons.append(f"already holding {symbol}; do not pyramid or average down via a new entry")
    if len(held) >= limits["max_open_positions"]:
        reasons.append(f"{len(held)} open positions (max {limits['max_open_positions']})")

    gross = sum(abs(_num(p.get("market_value"))) for p in positions)
    max_gross_pct = limits["max_gross_exposure_pct"]
    if regime_exposure_pct is not None:
        max_gross_pct = min(max_gross_pct, float(regime_exposure_pct))
    room = max(0.0, equity * max_gross_pct / 100 - gross)

    qty_by_risk = math.floor(equity * limits["risk_per_trade_pct"] / 100 / risk_per_share) if risk_per_share > 0 else 0
    qty_by_size = math.floor(equity * limits["max_position_pct"] / 100 / entry) if entry > 0 else 0
    qty_by_room = math.floor(room / entry) if entry > 0 else 0
    qty_by_cash = math.floor(capacity / entry) if entry > 0 else 0
    max_qty = max(0, min(qty_by_risk, qty_by_size, qty_by_room, qty_by_cash))
    binding = min(
        [("risk_per_trade", qty_by_risk), ("max_position", qty_by_size), ("exposure_room", qty_by_room), ("cash", qty_by_cash)],
        key=lambda kv: kv[1],
    )[0]

    qty = max_qty
    if requested_qty is not None:
        if requested_qty > max_qty:
            reasons.append(f"requested {requested_qty} shares exceeds the risk-approved maximum of {max_qty}")
        qty = min(int(requested_qty), max_qty)
    if not reasons and qty < 1:
        reasons.append(f"position size rounds to 0 shares (limited by {binding})")

    return {
        "approved": not reasons,
        "symbol": symbol,
        "qty": qty if not reasons else 0,
        "max_qty": max_qty,
        "binding_limit": binding,
        "entry": round(entry, 4),
        "stop": round(stop, 4),
        "target": round(float(target), 4) if target is not None else None,
        "stop_distance_pct": round(stop_pct, 2),
        "reward_risk": round(rr, 2) if rr is not None else None,
        "risk_dollars": round(qty * risk_per_share, 2) if not reasons else 0,
        "position_value": round(qty * entry, 2) if not reasons else 0,
        "position_pct_of_equity": round(qty * entry / equity * 100, 2) if equity > 0 and not reasons else 0,
        "exposure_after_pct": round((gross + (qty * entry if not reasons else 0)) / equity * 100, 2) if equity > 0 else None,
        "day_pl_pct": round(day_pl_pct, 2),
        "reasons": reasons,
        "warnings": warnings,
        "limits": limits,
    }


def main(argv=None) -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--symbol")
    ap.add_argument("--entry", type=float)
    ap.add_argument("--stop", type=float)
    ap.add_argument("--target", type=float)
    ap.add_argument("--qty", type=int, help="check a specific share count")
    ap.add_argument("--regime-exposure", type=float, help="cap gross exposure %% for the current market regime")
    ap.add_argument("--equity", type=float, help="offline mode: assume this equity and no positions")
    ap.add_argument("--show-limits", action="store_true")
    a = ap.parse_args(argv)

    if a.show_limits:
        print(json.dumps(load_limits(), indent=2))
        return
    if not (a.symbol and a.entry and a.stop):
        ap.error("--symbol, --entry and --stop are required")

    if a.equity is not None:
        account = {"equity": a.equity, "last_equity": a.equity, "buying_power": a.equity}
        positions = []
    else:
        import alpaca

        account, positions = alpaca.get_account(), alpaca.get_positions()

    result = evaluate(
        a.symbol, a.entry, a.stop, a.target, account, positions, a.qty, a.regime_exposure
    )
    print(json.dumps(result, indent=2))
    sys.exit(0 if result["approved"] else 2)


if __name__ == "__main__":
    main()
