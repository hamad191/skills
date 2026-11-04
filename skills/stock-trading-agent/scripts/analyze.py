#!/usr/bin/env python3
"""Multi-factor technical analysis, setup detection and market regime.

Inputs (pick one):
  python3 analyze.py AAPL MSFT NVDA --benchmark SPY       # fetch from Alpaca
  python3 analyze.py --file bars.json --benchmark SPY     # output of `alpaca.py bars`
  python3 analyze.py --csv AAPL.csv --csv SPY.csv --benchmark SPY   # Date,Open,High,Low,Close,Volume

Useful flags:
  --rank            sort by composite score (best first)
  --top N           keep the N best after ranking
  --table           human-readable table instead of JSON
  --regime-only     only print the market regime for the benchmark

Everything here is long-only and daily-bar based. Scores and setups are
evidence for a decision, not a decision: the agent still has to write the
thesis, check news/earnings and pass risk.py.
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import sys

import indicators as ind

MIN_BARS = 210  # SMA200 plus a little slack

# Default trade geometry per setup: stop = entry - stop_atr * ATR,
# target = entry + target_r * (entry - stop), exit after max_hold bars.
SETUP_RULES = {
    "trend_pullback": {"stop_atr": 2.0, "target_r": 2.5, "max_hold": 30},
    "breakout": {"stop_atr": 2.0, "target_r": 2.5, "max_hold": 30},
    "mean_reversion": {"stop_atr": 1.5, "target_r": 2.0, "max_hold": 10},
}


# ---------------------------------------------------------------- data loading


def bars_from_alpaca(rows) -> dict:
    rows = sorted(rows, key=lambda r: r["t"])
    return {
        "t": [str(r["t"])[:10] for r in rows],
        "o": [float(r["o"]) for r in rows],
        "h": [float(r["h"]) for r in rows],
        "l": [float(r["l"]) for r in rows],
        "c": [float(r["c"]) for r in rows],
        "v": [float(r.get("v", 0) or 0) for r in rows],
    }


def bars_from_csv(path: str) -> dict:
    with open(path, newline="") as fh:
        reader = csv.DictReader(fh)
        cols = {name.lower().strip(): name for name in (reader.fieldnames or [])}

        def col(*names):
            for n in names:
                if n in cols:
                    return cols[n]
            raise SystemExit(f"{path}: missing column, expected one of {names}")

        tc = col("date", "timestamp", "time", "t")
        oc, hc, lc = col("open", "o"), col("high", "h"), col("low", "l")
        cc = cols.get("adj close") or col("close", "c")
        vc = cols.get("volume") or cols.get("v")
        rows = []
        for r in reader:
            try:
                rows.append(
                    {
                        "t": r[tc],
                        "o": float(r[oc]),
                        "h": float(r[hc]),
                        "l": float(r[lc]),
                        "c": float(r[cc]),
                        "v": float(r[vc]) if vc and r.get(vc) else 0.0,
                    }
                )
            except (TypeError, ValueError):
                continue  # skip malformed / null rows
    return bars_from_alpaca(rows)


def load_universe(args) -> dict:
    """Return {SYMBOL: bars} from --file, --csv or Alpaca."""
    data: dict = {}
    if args.file:
        with open(args.file) as fh:
            raw = json.load(fh)
        for sym, rows in raw.items():
            data[sym.upper()] = bars_from_alpaca(rows)
    for path in args.csv or []:
        sym = os.path.splitext(os.path.basename(path))[0].split(".")[0].upper()
        data[sym] = bars_from_csv(path)
    if not data:
        if not args.symbols:
            raise SystemExit("give symbols, --file or --csv")
        import alpaca

        wanted = [s.upper() for s in args.symbols]
        if args.benchmark and args.benchmark.upper() not in wanted:
            wanted.append(args.benchmark.upper())
        for sym, rows in alpaca.get_bars(wanted, days=args.days).items():
            data[sym] = bars_from_alpaca(rows)
    return data


# ---------------------------------------------------------------- indicators


def compute(bars: dict) -> dict:
    c, h, l, v = bars["c"], bars["h"], bars["l"], bars["v"]
    macd_line, macd_sig, macd_hist = ind.macd(c)
    adx, pdi, mdi = ind.adx(h, l, c)
    _, bb_up, bb_lo, pctb = ind.bollinger(c)
    return {
        "bars": bars,
        "sma20": ind.sma(c, 20),
        "sma50": ind.sma(c, 50),
        "sma200": ind.sma(c, 200),
        "ema10": ind.ema(c, 10),
        "rsi14": ind.rsi(c, 14),
        "macd": macd_line,
        "macd_signal": macd_sig,
        "macd_hist": macd_hist,
        "atr14": ind.atr(h, l, c, 14),
        "adx14": adx,
        "plus_di": pdi,
        "minus_di": mdi,
        "bb_upper": bb_up,
        "bb_lower": bb_lo,
        "pctb": pctb,
        "vol_sma20": ind.sma(v, 20),
        "high20_prior": ind.rolling_max(h, 20, exclude_current=True),
        "low5": ind.rolling_min(l, 5),
        "high252": ind.rolling_max(h, 252),
        "ret21": ind.pct_change(c, 21),
        "ret63": ind.pct_change(c, 63),
        "ret126": ind.pct_change(c, 126),
        "rvol20": ind.realized_vol(c, 20),
    }


def _r(x, nd=2):
    return round(x, nd) if isinstance(x, (int, float)) else None


def metrics_at(series: dict, i: int, bench: dict | None = None) -> dict | None:
    """Snapshot of every factor at bar ``i`` (causal). None if history is too short."""
    b = series["bars"]
    need = ("sma200", "sma50", "sma20", "rsi14", "atr14", "macd_hist", "adx14")
    if i < 0 or any(series[k][i] is None for k in need):
        return None
    c = b["c"][i]
    atr = series["atr14"][i]
    s50_prev = series["sma50"][i - 10] if i >= 10 else None
    vol_avg = series["vol_sma20"][i]
    day_range = b["h"][i] - b["l"][i]
    m = {
        "date": b["t"][i],
        "open": b["o"][i],
        "high": b["h"][i],
        "low": b["l"][i],
        "close": c,
        "prev_close": b["c"][i - 1] if i > 0 else None,
        "sma20": series["sma20"][i],
        "sma50": series["sma50"][i],
        "sma200": series["sma200"][i],
        "sma50_slope_pct": (series["sma50"][i] / s50_prev - 1) * 100 if s50_prev else None,
        "rsi14": series["rsi14"][i],
        "macd_hist": series["macd_hist"][i],
        "macd_hist_prev": series["macd_hist"][i - 1] if i > 0 else None,
        "adx14": series["adx14"][i],
        "plus_di": series["plus_di"][i],
        "minus_di": series["minus_di"][i],
        "atr14": atr,
        "atr_pct": atr / c * 100 if c else None,
        "pctb": series["pctb"][i],
        "rel_volume": b["v"][i] / vol_avg if vol_avg else None,
        "close_location": (c - b["l"][i]) / day_range if day_range > 0 else 0.5,
        "high20_prior": series["high20_prior"][i],
        "low5": series["low5"][i],
        "high252": series["high252"][i],
        "ret_1m": series["ret21"][i],
        "ret_3m": series["ret63"][i],
        "ret_6m": series["ret126"][i],
        "realized_vol_20d": series["rvol20"][i],
        "rs_3m": None,
    }
    m["pct_from_52w_high"] = (c / m["high252"] - 1) * 100 if m["high252"] else None
    if bench is not None and m["ret_3m"] is not None:
        bi = bench["index"].get(m["date"])
        if bi is not None and bench["series"]["ret63"][bi] is not None:
            m["rs_3m"] = m["ret_3m"] - bench["series"]["ret63"][bi]
    return m


# ---------------------------------------------------------------- setups & score


def detect_setups(m: dict) -> list:
    """Return the long setups that trigger on this bar."""
    out = []
    c, atr = m["close"], m["atr14"]
    uptrend = c > m["sma200"] and m["sma50"] > m["sma200"]
    rising = (m["sma50_slope_pct"] or 0) > 0
    bullish_bar = c > m["open"] or (m["prev_close"] is not None and c > m["prev_close"])
    macd_turning = (
        m["macd_hist_prev"] is not None and m["macd_hist"] > m["macd_hist_prev"]
    )

    # 1) Pullback to the 20/50-day average inside an established uptrend.
    near_ma = m["low"] <= m["sma20"] + 0.5 * atr or m["low"] <= m["sma50"] + 0.5 * atr
    if uptrend and rising and 38 <= m["rsi14"] <= 55 and near_ma and bullish_bar and macd_turning and c > m["sma50"] - 0.5 * atr:
        out.append("trend_pullback")

    # 2) Breakout to a new 20-day high on expanding volume with a strong close.
    if (
        m["high20_prior"] is not None
        and c > m["high20_prior"]
        and (m["rel_volume"] or 0) >= 1.5
        and c > m["sma50"] > m["sma200"]
        and m["adx14"] >= 20
        and (m["plus_di"] or 0) > (m["minus_di"] or 0)
        and m["close_location"] >= 0.7
        and m["rsi14"] < 78
    ):
        out.append("breakout")

    # 3) Short-term oversold bounce, only above the 200-day average.
    oversold = m["rsi14"] < 32 or ((m["pctb"] is not None and m["pctb"] < 0.0) and m["rsi14"] < 40)
    if c > m["sma200"] and oversold and bullish_bar:
        out.append("mean_reversion")
    return out


def trade_plan(m: dict, setup: str, rules=None) -> dict:
    rule = (rules or SETUP_RULES)[setup]
    entry = m["close"]
    stop = entry - rule["stop_atr"] * m["atr14"]
    # Structure-aware: if the recent swing low is closer (but > 1 ATR away), use it.
    if m["low5"] is not None:
        swing = m["low5"] - 0.25 * m["atr14"]
        if entry - m["atr14"] >= swing > stop:
            stop = swing
    target = entry + rule["target_r"] * (entry - stop)
    return {
        "setup": setup,
        "entry_ref": _r(entry),
        "stop": _r(stop),
        "target": _r(target),
        "reward_risk": rule["target_r"],
        "max_hold_days": rule["max_hold"],
        "stop_distance_pct": _r((entry - stop) / entry * 100),
    }


def _clamp(x, lo, hi):
    return max(lo, min(hi, x))


def score(m: dict) -> dict:
    c = m["close"]
    trend = (
        10 * (c > m["sma200"])
        + 8 * (m["sma50"] > m["sma200"])
        + 6 * (c > m["sma50"])
        + 6 * ((m["sma50_slope_pct"] or 0) > 0)
    )
    mom = 0.0
    if m["ret_3m"] is not None:
        mom += 10 * (_clamp(m["ret_3m"], -20, 40) + 20) / 60
    if m["ret_6m"] is not None:
        mom += 5 * (_clamp(m["ret_6m"], -30, 60) + 30) / 90
    mom += 5 * (m["macd_hist"] > 0)
    r = m["rsi14"]
    mom += 5 if 45 <= r <= 70 else 2 if 70 < r <= 80 or 38 <= r < 45 else 0
    rs = 10.0 if m["rs_3m"] is None else 20 * (_clamp(m["rs_3m"], -15, 15) + 15) / 30
    bull_di = (m["plus_di"] or 0) > (m["minus_di"] or 0)
    strength = 10 if m["adx14"] >= 25 and bull_di else 6 if m["adx14"] >= 20 and bull_di else 3 if bull_di else 0
    ap = m["atr_pct"] or 99
    quality = 15 if ap <= 3 else 10 if ap <= 4.5 else 5 if ap <= 6 else 0
    parts = {
        "trend": round(trend, 1),
        "momentum": round(mom, 1),
        "relative_strength": round(rs, 1),
        "trend_strength": strength,
        "volatility_quality": quality,
    }
    parts["total"] = round(sum(parts.values()), 1)
    return parts


def warnings_for(m: dict) -> list:
    w = []
    if m["close"] < m["sma200"]:
        w.append("below 200-day average: long trades fight the primary trend")
    if m["sma50"] < m["sma200"]:
        w.append("50-day below 200-day (death-cross structure)")
    if m["rsi14"] > 75:
        w.append(f"RSI {m['rsi14']:.0f}: extended, do not chase")
    if (m["atr_pct"] or 0) > 6:
        w.append(f"ATR is {m['atr_pct']:.1f}% of price: very volatile, size down")
    if m["prev_close"] and abs(m["open"] / m["prev_close"] - 1) > 0.04:
        w.append("gapped >4% today: likely news, check before acting")
    if m["pct_from_52w_high"] is not None and m["pct_from_52w_high"] < -35:
        w.append("more than 35% below its 52-week high")
    return w


def market_regime(m: dict) -> dict:
    """Classify the benchmark (e.g. SPY) into risk_on / neutral / risk_off."""
    c = m["close"]
    if c > m["sma200"] and m["sma50"] > m["sma200"] and c > m["sma50"]:
        label, exposure = "risk_on", 90
        allowed = ["trend_pullback", "breakout", "mean_reversion"]
    elif c > m["sma200"] or (m["sma50"] > m["sma200"] and c > m["sma200"] * 0.97):
        label, exposure = "neutral", 50
        allowed = ["trend_pullback", "mean_reversion"]
    else:
        label, exposure = "risk_off", 20
        allowed = ["mean_reversion"]
    notes = []
    vol = m["realized_vol_20d"]
    if vol is not None and vol > 25:
        exposure = exposure // 2
        notes.append(f"benchmark realized vol {vol:.0f}% > 25%: exposure halved")
    if label != "risk_on":
        notes.append("prefer cash; only A-grade setups (score >= 70)")
    return {
        "label": label,
        "max_exposure_pct": exposure,
        "allowed_setups": allowed,
        "min_score": 60 if label == "risk_on" else 70,
        "benchmark_close": _r(c),
        "benchmark_vs_sma200_pct": _r((c / m["sma200"] - 1) * 100),
        "benchmark_ret_1m": _r(m["ret_1m"]),
        "benchmark_realized_vol_20d": _r(vol),
        "notes": notes,
    }


# ---------------------------------------------------------------- report


def analyze_symbol(sym: str, bars: dict, bench=None) -> dict:
    if len(bars["c"]) < MIN_BARS:
        return {"symbol": sym, "error": f"only {len(bars['c'])} bars; need >= {MIN_BARS} daily bars"}
    series = compute(bars)
    m = metrics_at(series, len(bars["c"]) - 1, bench)
    if m is None:
        return {"symbol": sym, "error": "insufficient history for indicators"}
    setups = detect_setups(m)
    return {
        "symbol": sym,
        "date": m["date"],
        "close": _r(m["close"]),
        "score": score(m),
        "setups": setups,
        "plans": [trade_plan(m, s) for s in setups],
        "warnings": warnings_for(m),
        "trend": {
            "sma20": _r(m["sma20"]),
            "sma50": _r(m["sma50"]),
            "sma200": _r(m["sma200"]),
            "sma50_slope_10d_pct": _r(m["sma50_slope_pct"]),
            "adx14": _r(m["adx14"], 1),
            "plus_di": _r(m["plus_di"], 1),
            "minus_di": _r(m["minus_di"], 1),
        },
        "momentum": {
            "rsi14": _r(m["rsi14"], 1),
            "macd_hist": _r(m["macd_hist"], 3),
            "ret_1m_pct": _r(m["ret_1m"]),
            "ret_3m_pct": _r(m["ret_3m"]),
            "ret_6m_pct": _r(m["ret_6m"]),
            "rs_vs_benchmark_3m_pct": _r(m["rs_3m"]),
        },
        "volatility": {
            "atr14": _r(m["atr14"]),
            "atr_pct": _r(m["atr_pct"]),
            "realized_vol_20d_pct": _r(m["realized_vol_20d"]),
            "bollinger_pctb": _r(m["pctb"]),
        },
        "volume": {"rel_volume_20d": _r(m["rel_volume"])},
        "levels": {
            "prior_20d_high": _r(m["high20_prior"]),
            "low_5d": _r(m["low5"]),
            "high_52w": _r(m["high252"]),
            "pct_from_52w_high": _r(m["pct_from_52w_high"]),
        },
    }


def bench_context(bars: dict | None):
    if not bars or len(bars["c"]) < MIN_BARS:
        return None
    series = compute(bars)
    return {"series": series, "index": {t: i for i, t in enumerate(bars["t"])}}


def print_table(regime, rows) -> None:
    if regime:
        print(f"Regime: {regime['label']}  max exposure {regime['max_exposure_pct']}%  "
              f"allowed {','.join(regime['allowed_setups'])}  min score {regime['min_score']}")
        for n in regime["notes"]:
            print(f"  - {n}")
    print(f"{'SYM':<7}{'SCORE':>6}{'CLOSE':>10}{'RSI':>6}{'ATR%':>6}{'RS3M':>7}  SETUPS / WARNINGS")
    for r in rows:
        if "error" in r:
            print(f"{r['symbol']:<7}  error: {r['error']}")
            continue
        rs = r["momentum"]["rs_vs_benchmark_3m_pct"]
        print(
            f"{r['symbol']:<7}{r['score']['total']:>6.0f}{r['close']:>10.2f}"
            f"{r['momentum']['rsi14']:>6.0f}{r['volatility']['atr_pct']:>6.1f}"
            f"{(rs if rs is not None else 0):>7.1f}  {','.join(r['setups']) or '-'}"
            + (f"  ! {r['warnings'][0]}" if r["warnings"] else "")
        )


def main(argv=None) -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("symbols", nargs="*")
    ap.add_argument("--file", help="JSON bars file from `alpaca.py bars --out`")
    ap.add_argument("--csv", action="append", help="CSV file per symbol (repeatable)")
    ap.add_argument("--benchmark", default="SPY", help="benchmark for regime and relative strength ('' to disable)")
    ap.add_argument("--days", type=int, default=420, help="calendar days of history to fetch")
    ap.add_argument("--rank", action="store_true")
    ap.add_argument("--top", type=int)
    ap.add_argument("--table", action="store_true")
    ap.add_argument("--regime-only", action="store_true")
    a = ap.parse_args(argv)

    data = load_universe(a)
    bsym = (a.benchmark or "").upper()
    bench = bench_context(data.get(bsym)) if bsym else None
    regime = None
    if bench:
        bm = metrics_at(bench["series"], len(bench["series"]["bars"]["c"]) - 1)
        regime = market_regime(bm) if bm else None
    if a.regime_only:
        print(json.dumps(regime or {"error": f"no usable bars for benchmark {bsym!r}"}, indent=2))
        return

    wanted = [s.upper() for s in a.symbols] or [s for s in data if s != bsym]
    rows = [analyze_symbol(s, data[s], bench) if s in data else {"symbol": s, "error": "no data"} for s in wanted]
    if a.rank or a.top:
        rows.sort(key=lambda r: r.get("score", {}).get("total", -1), reverse=True)
    if a.top:
        rows = rows[: a.top]
    if regime:
        for r in rows:
            if "setups" in r:
                r["setups_allowed_by_regime"] = [s for s in r["setups"] if s in regime["allowed_setups"]]
                r["actionable"] = bool(r["setups_allowed_by_regime"]) and r["score"]["total"] >= regime["min_score"]

    if a.table:
        print_table(regime, rows)
    else:
        print(json.dumps({"regime": regime, "results": rows}, indent=2))


if __name__ == "__main__":
    sys.exit(main())
