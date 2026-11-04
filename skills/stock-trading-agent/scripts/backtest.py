#!/usr/bin/env python3
"""Walk-forward backtest of the analyze.py setups on daily bars.

Rules (no look-ahead):
  * a signal is evaluated on the close of bar i using only data up to bar i
  * entry is the OPEN of bar i+1; the trade is skipped if it gaps below the stop
  * stop / target are checked every bar; if both are touched on the same bar
    the stop is assumed to fill first (pessimistic); gaps fill at the open
  * time stop: exit at the close after max_hold bars
  * costs: --cost-bps per side (slippage + fees)
  * one position per symbol at a time; results are reported in R multiples
    (R = initial risk per share) and as equity compounded at --risk-pct per trade

Examples:
  python3 backtest.py AAPL MSFT NVDA --benchmark SPY --days 2500
  python3 backtest.py --file bars.json --setup trend_pullback --stop-atr 2.5
  python3 backtest.py --csv AAPL.csv --csv SPY.csv --benchmark SPY --no-regime
"""

from __future__ import annotations

import argparse
import json
import sys

import analyze as an


def _stats(trades: list, risk_pct: float) -> dict:
    if not trades:
        return {"trades": 0}
    rs = [t["r"] for t in trades]
    wins = [r for r in rs if r > 0]
    losses = [r for r in rs if r <= 0]
    equity, peak, max_dd = 1.0, 1.0, 0.0
    cum, cum_peak, max_dd_r = 0.0, 0.0, 0.0
    for r in rs:
        equity *= 1 + risk_pct / 100 * r
        peak = max(peak, equity)
        max_dd = max(max_dd, (peak - equity) / peak)
        cum += r
        cum_peak = max(cum_peak, cum)
        max_dd_r = max(max_dd_r, cum_peak - cum)
    gross_win, gross_loss = sum(wins), -sum(losses)
    return {
        "trades": len(rs),
        "win_rate_pct": round(len(wins) / len(rs) * 100, 1),
        "avg_win_r": round(gross_win / len(wins), 2) if wins else 0,
        "avg_loss_r": round(-gross_loss / len(losses), 2) if losses else 0,
        "expectancy_r": round(sum(rs) / len(rs), 3),
        "profit_factor": round(gross_win / gross_loss, 2) if gross_loss else None,
        "total_r": round(sum(rs), 2),
        "max_drawdown_r": round(max_dd_r, 2),
        "avg_hold_bars": round(sum(t["bars"] for t in trades) / len(trades), 1),
        f"return_at_{risk_pct:g}pct_risk_pct": round((equity - 1) * 100, 2),
        "max_drawdown_pct": round(max_dd * 100, 2),
        "exits": {k: sum(1 for t in trades if t["exit_reason"] == k) for k in ("stop", "target", "time")},
    }


def run_symbol(sym, bars, bench, setups, rules, min_score, use_regime, cost_bps) -> dict:
    series = an.compute(bars)
    o, h, l, c, t = bars["o"], bars["h"], bars["l"], bars["c"], bars["t"]
    cost = cost_bps / 10000.0
    trades, pos, pending = [], None, None
    bars_in_market = 0
    first_signal_bar = None

    for i in range(len(c)):
        # 1) fill a pending entry at today's open
        if pending is not None and pos is None:
            entry = o[i]
            if entry > pending["stop"]:
                risk = entry - pending["stop"]
                pos = {
                    "setup": pending["setup"],
                    "entry_date": t[i],
                    "entry": entry,
                    "stop": pending["stop"],
                    "target": entry + pending["rule"]["target_r"] * risk,
                    "risk": risk,
                    "max_hold": pending["rule"]["max_hold"],
                    "bars": 0,
                    "score": pending["score"],
                }
            pending = None

        # 2) manage an open position on this bar
        if pos is not None:
            pos["bars"] += 1
            bars_in_market += 1
            exit_px = reason = None
            if o[i] <= pos["stop"]:
                exit_px, reason = o[i], "stop"
            elif l[i] <= pos["stop"]:
                exit_px, reason = pos["stop"], "stop"
            elif o[i] >= pos["target"]:
                exit_px, reason = o[i], "target"
            elif h[i] >= pos["target"]:
                exit_px, reason = pos["target"], "target"
            elif pos["bars"] >= pos["max_hold"]:
                exit_px, reason = c[i], "time"
            if exit_px is not None:
                net = exit_px * (1 - cost) - pos["entry"] * (1 + cost)
                trades.append(
                    {
                        "symbol": sym,
                        "setup": pos["setup"],
                        "entry_date": pos["entry_date"],
                        "exit_date": t[i],
                        "entry": round(pos["entry"], 2),
                        "exit": round(exit_px, 2),
                        "r": round(net / pos["risk"], 3),
                        "bars": pos["bars"],
                        "exit_reason": reason,
                        "score": pos["score"],
                    }
                )
                pos = None
            continue  # no new signal while a position was open today

        # 3) look for a new signal on today's close
        if i == len(c) - 1:
            break
        m = an.metrics_at(series, i, bench)
        if m is None:
            continue
        if first_signal_bar is None:
            first_signal_bar = i
        hits = [s for s in an.detect_setups(m) if s in setups]
        if not hits:
            continue
        sc = an.score(m)["total"]
        threshold = min_score
        if use_regime and bench is not None:
            bi = bench["index"].get(m["date"])
            bm = an.metrics_at(bench["series"], bi) if bi is not None else None
            if bm is None:
                continue
            reg = an.market_regime(bm)
            hits = [s for s in hits if s in reg["allowed_setups"]]
            threshold = max(threshold, reg["min_score"])
        if not hits or sc < threshold:
            continue
        setup = hits[0]
        plan = an.trade_plan(m, setup, rules)
        pending = {"setup": setup, "stop": plan["stop"], "rule": rules[setup], "score": sc}

    start = first_signal_bar if first_signal_bar is not None else 0
    tested_bars = max(1, len(c) - start)
    return {
        "symbol": sym,
        "from": t[start] if c else None,
        "to": t[-1] if c else None,
        "buy_hold_return_pct": round((c[-1] / c[start] - 1) * 100, 2) if c else None,
        "time_in_market_pct": round(bars_in_market / tested_bars * 100, 1),
        "trades": trades,
    }


def main(argv=None) -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("symbols", nargs="*")
    ap.add_argument("--file")
    ap.add_argument("--csv", action="append")
    ap.add_argument("--benchmark", default="SPY")
    ap.add_argument("--days", type=int, default=2500, help="calendar days to fetch (~7 years)")
    ap.add_argument("--setup", action="append", choices=list(an.SETUP_RULES), help="restrict to setup(s)")
    ap.add_argument("--min-score", type=float, default=60)
    ap.add_argument("--no-regime", action="store_true", help="ignore the benchmark regime filter")
    ap.add_argument("--stop-atr", type=float, help="override stop distance in ATRs for all setups")
    ap.add_argument("--target-r", type=float, help="override target in R for all setups")
    ap.add_argument("--max-hold", type=int, help="override time stop in bars for all setups")
    ap.add_argument("--cost-bps", type=float, default=5.0, help="cost per side in basis points")
    ap.add_argument("--risk-pct", type=float, default=1.0, help="equity risked per trade for the equity curve")
    ap.add_argument("--trades", action="store_true", help="include the trade list")
    a = ap.parse_args(argv)

    rules = {k: dict(v) for k, v in an.SETUP_RULES.items()}
    for rule in rules.values():
        if a.stop_atr:
            rule["stop_atr"] = a.stop_atr
        if a.target_r:
            rule["target_r"] = a.target_r
        if a.max_hold:
            rule["max_hold"] = a.max_hold
    setups = a.setup or list(rules)

    data = an.load_universe(a)
    bsym = (a.benchmark or "").upper()
    bench = an.bench_context(data.get(bsym)) if bsym else None
    wanted = [s.upper() for s in a.symbols] or [s for s in data if s != bsym]

    per_symbol, all_trades = [], []
    for sym in wanted:
        if sym not in data or len(data[sym]["c"]) < an.MIN_BARS:
            per_symbol.append({"symbol": sym, "error": "not enough data"})
            continue
        res = run_symbol(sym, data[sym], bench, setups, rules, a.min_score, not a.no_regime, a.cost_bps)
        all_trades.extend(res["trades"])
        summary = {k: v for k, v in res.items() if k != "trades"}
        summary.update(_stats(res["trades"], a.risk_pct))
        if a.trades:
            summary["trade_list"] = res["trades"]
        per_symbol.append(summary)

    all_trades.sort(key=lambda tr: tr["exit_date"])
    by_setup = {s: _stats([tr for tr in all_trades if tr["setup"] == s], a.risk_pct) for s in setups}
    report = {
        "config": {
            "setups": setups,
            "rules": {s: rules[s] for s in setups},
            "min_score": a.min_score,
            "regime_filter": bool(bench) and not a.no_regime,
            "cost_bps_per_side": a.cost_bps,
        },
        "overall": _stats(all_trades, a.risk_pct),
        "by_setup": by_setup,
        "by_symbol": per_symbol,
        "caveats": [
            "past performance does not predict future results",
            "overall stats pool trades across symbols; overlapping trades are not capital-constrained",
            "fewer than ~30 trades is too small a sample to trust",
            "IEX-only volume understates consolidated volume; breakout volume filters are approximate",
        ],
    }
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    sys.exit(main())
