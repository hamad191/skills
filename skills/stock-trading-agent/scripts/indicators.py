"""Causal technical indicators (stdlib only).

Every function returns a list the same length as its input. Index ``i`` only
uses data at or before ``i`` (no look-ahead), so the outputs are safe to use
in backtests. Positions without enough history are ``None``.
"""

from __future__ import annotations

import math
from typing import List, Optional, Sequence

Series = List[Optional[float]]


def sma(values: Sequence[float], n: int) -> Series:
    out: Series = [None] * len(values)
    total = 0.0
    for i, v in enumerate(values):
        total += v
        if i >= n:
            total -= values[i - n]
        if i >= n - 1:
            out[i] = total / n
    return out


def ema(values: Sequence[float], n: int) -> Series:
    out: Series = [None] * len(values)
    if len(values) < n:
        return out
    k = 2.0 / (n + 1)
    prev = sum(values[:n]) / n
    out[n - 1] = prev
    for i in range(n, len(values)):
        prev = values[i] * k + prev * (1 - k)
        out[i] = prev
    return out


def _wilder(values: Sequence[float], n: int, start: int) -> Series:
    """Wilder smoothing of ``values`` beginning at index ``start``."""
    out: Series = [None] * len(values)
    if len(values) < start + n:
        return out
    prev = sum(values[start : start + n]) / n
    out[start + n - 1] = prev
    for i in range(start + n, len(values)):
        prev = (prev * (n - 1) + values[i]) / n
        out[i] = prev
    return out


def rsi(closes: Sequence[float], n: int = 14) -> Series:
    out: Series = [None] * len(closes)
    if len(closes) <= n:
        return out
    gains = [0.0] + [max(closes[i] - closes[i - 1], 0.0) for i in range(1, len(closes))]
    losses = [0.0] + [max(closes[i - 1] - closes[i], 0.0) for i in range(1, len(closes))]
    avg_gain = _wilder(gains, n, 1)
    avg_loss = _wilder(losses, n, 1)
    for i in range(len(closes)):
        g, l = avg_gain[i], avg_loss[i]
        if g is None or l is None:
            continue
        if l == 0:
            out[i] = 100.0 if g > 0 else 50.0
        else:
            out[i] = 100.0 - 100.0 / (1.0 + g / l)
    return out


def macd(closes: Sequence[float], fast: int = 12, slow: int = 26, signal: int = 9):
    """Return (macd_line, signal_line, histogram)."""
    ef, es = ema(closes, fast), ema(closes, slow)
    line: Series = [
        (f - s) if f is not None and s is not None else None for f, s in zip(ef, es)
    ]
    first = next((i for i, v in enumerate(line) if v is not None), None)
    sig: Series = [None] * len(closes)
    if first is not None:
        tail = ema([v for v in line[first:]], signal)  # type: ignore[misc]
        sig[first:] = tail
    hist: Series = [
        (m - s) if m is not None and s is not None else None for m, s in zip(line, sig)
    ]
    return line, sig, hist


def true_range(highs: Sequence[float], lows: Sequence[float], closes: Sequence[float]):
    tr = []
    for i in range(len(closes)):
        if i == 0:
            tr.append(highs[0] - lows[0])
        else:
            pc = closes[i - 1]
            tr.append(max(highs[i] - lows[i], abs(highs[i] - pc), abs(lows[i] - pc)))
    return tr


def atr(highs, lows, closes, n: int = 14) -> Series:
    return _wilder(true_range(highs, lows, closes), n, 1) if len(closes) > n else [None] * len(closes)


def adx(highs, lows, closes, n: int = 14):
    """Return (adx, plus_di, minus_di)."""
    size = len(closes)
    plus_dm = [0.0] * size
    minus_dm = [0.0] * size
    for i in range(1, size):
        up = highs[i] - highs[i - 1]
        down = lows[i - 1] - lows[i]
        plus_dm[i] = up if up > down and up > 0 else 0.0
        minus_dm[i] = down if down > up and down > 0 else 0.0
    tr = true_range(highs, lows, closes)
    s_tr = _wilder(tr, n, 1)
    s_p = _wilder(plus_dm, n, 1)
    s_m = _wilder(minus_dm, n, 1)
    pdi: Series = [None] * size
    mdi: Series = [None] * size
    dx = [0.0] * size
    dx_start = None
    for i in range(size):
        t, p, m = s_tr[i], s_p[i], s_m[i]
        if t is None or p is None or m is None or t == 0:
            continue
        pdi[i] = 100.0 * p / t
        mdi[i] = 100.0 * m / t
        denom = pdi[i] + mdi[i]
        dx[i] = 100.0 * abs(pdi[i] - mdi[i]) / denom if denom else 0.0
        if dx_start is None:
            dx_start = i
    adx_out: Series = [None] * size
    if dx_start is not None:
        adx_out = _wilder(dx, n, dx_start)
    return adx_out, pdi, mdi


def bollinger(closes: Sequence[float], n: int = 20, k: float = 2.0):
    """Return (middle, upper, lower, percent_b)."""
    mid = sma(closes, n)
    upper: Series = [None] * len(closes)
    lower: Series = [None] * len(closes)
    pctb: Series = [None] * len(closes)
    for i in range(n - 1, len(closes)):
        window = closes[i - n + 1 : i + 1]
        m = mid[i]
        sd = math.sqrt(sum((x - m) ** 2 for x in window) / n)  # type: ignore[operator]
        upper[i] = m + k * sd  # type: ignore[operator]
        lower[i] = m - k * sd  # type: ignore[operator]
        width = upper[i] - lower[i]  # type: ignore[operator]
        pctb[i] = (closes[i] - lower[i]) / width if width else 0.5  # type: ignore[operator]
    return mid, upper, lower, pctb


def rolling_max(values: Sequence[float], n: int, exclude_current: bool = False) -> Series:
    out: Series = [None] * len(values)
    off = 1 if exclude_current else 0
    for i in range(len(values)):
        end = i + 1 - off
        start = end - n
        if start < 0:
            continue
        out[i] = max(values[start:end])
    return out


def rolling_min(values: Sequence[float], n: int, exclude_current: bool = False) -> Series:
    out: Series = [None] * len(values)
    off = 1 if exclude_current else 0
    for i in range(len(values)):
        end = i + 1 - off
        start = end - n
        if start < 0:
            continue
        out[i] = min(values[start:end])
    return out


def pct_change(values: Sequence[float], n: int) -> Series:
    out: Series = [None] * len(values)
    for i in range(n, len(values)):
        if values[i - n]:
            out[i] = (values[i] / values[i - n] - 1.0) * 100.0
    return out


def realized_vol(closes: Sequence[float], n: int = 20) -> Series:
    """Annualized close-to-close volatility in percent."""
    out: Series = [None] * len(closes)
    rets = [0.0] + [
        math.log(closes[i] / closes[i - 1]) if closes[i - 1] > 0 and closes[i] > 0 else 0.0
        for i in range(1, len(closes))
    ]
    for i in range(n, len(closes)):
        window = rets[i - n + 1 : i + 1]
        mean = sum(window) / n
        var = sum((r - mean) ** 2 for r in window) / (n - 1)
        out[i] = math.sqrt(var) * math.sqrt(252) * 100.0
    return out
