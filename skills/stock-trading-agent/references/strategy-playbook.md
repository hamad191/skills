# Strategy Playbook

All setups are long-only and use daily bars. They are implemented in
`scripts/analyze.py` (`detect_setups`, `trade_plan`, `score`, `market_regime`),
and `scripts/backtest.py` tests exactly the same code.

## Composite score (0–100)

| Component            | Points | What earns them                                                                    |
| -------------------- | ------ | ---------------------------------------------------------------------------------- |
| `trend`              | 30     | close > SMA200 (10), SMA50 > SMA200 (8), close > SMA50 (6), SMA50 rising over 10 days (6) |
| `momentum`           | 25     | 3-month return (10), 6-month return (5), MACD histogram > 0 (5), RSI in 45–70 (5)  |
| `relative_strength`  | 20     | 3-month return minus the benchmark's, mapped from −15%…+15% (10 if no benchmark)   |
| `trend_strength`     | 10     | ADX ≥ 25 with +DI > −DI (10), ADX ≥ 20 (6), +DI > −DI only (3)                     |
| `volatility_quality` | 15     | ATR% ≤ 3 (15), ≤ 4.5 (10), ≤ 6 (5), otherwise 0                                    |

Rough reading: 80 or more is a market leader, 60–80 is tradable, under 50 is avoid
territory for longs. A score is context, not a signal. A setup has to trigger as well.

## Setups

### `trend_pullback`: buy weakness in strength

- Uptrend: close > SMA200, SMA50 > SMA200, SMA50 rising
- Pullback: RSI14 between 38 and 55, and the day's low within 0.5 ATR of the SMA20 or SMA50
- Trigger: a bullish bar (close > open or close > prior close), with the MACD histogram rising
- Not broken: close no more than 0.5 ATR below the SMA50
- Plan: stop 2 ATR below the entry (or just under the 5-day swing low if that is
  closer but still at least 1 ATR away), target 2.5R, time stop 30 bars
- Best in `risk_on`. Acceptable in `neutral` for names with top relative strength.
- Good signs: the pullback came on falling volume, the sector ETF is also above
  its SMA50, and there is a nearby prior breakout level acting as support.
- Red flags: the pullback came on heavy volume (distribution), it was a news-driven
  drop, or the market itself is breaking down.

### `breakout`: buy strength as it expands

- Close above the prior 20-day high
- Relative volume ≥ 1.5× the 20-day average
- close > SMA50 > SMA200, ADX ≥ 20 with +DI > −DI
- Strong close: in the top 30% of the day's range. RSI < 78 (not exhausted).
- Plan: stop 2 ATR below, target 2.5R, time stop 30 bars
- Only in `risk_on`. Breakouts fail far more often in weak markets.
- Good signs: a tight base (falling ATR before the breakout), a first breakout after a
  long base, a new 52-week high.
- Red flags: the third or later breakout of the same advance, a breakout into earnings,
  or a gap-and-fade intraday.
- Note: the free IEX feed reports only part of consolidated volume, so relative
  volume is approximate.

### `mean_reversion`: oversold bounce inside an uptrend

- close > SMA200 (never catch falling knives in downtrends)
- RSI14 < 32, or close below the lower Bollinger band with RSI14 < 40
- Trigger: a bullish bar
- Plan: stop 1.5 ATR below, target 2R (usually around the SMA20), time stop 10 bars
- The only setup allowed in `risk_off`, and then at reduced exposure.
- Red flags: the selloff is due to fundamentals (an earnings miss, guidance cut, or
  downgrade on a real issue) rather than market-wide noise.

## Market regime (benchmark, usually SPY)

| Label      | Condition                                                         | Exposure | Setups            |
| ---------- | ----------------------------------------------------------------- | -------- | ----------------- |
| `risk_on`  | close > SMA50 > SMA200 and close > SMA200                         | 90%      | all               |
| `neutral`  | above SMA200 but not fully aligned, or just below with SMA50 > SMA200 | 50%  | pullback, reversion |
| `risk_off` | anything else                                                     | 20%      | reversion only    |

If the benchmark's 20-day realized volatility is above 25%, exposure is halved.
Confirm the picture with QQQ (growth) and IWM (breadth). If IWM is in `risk_off`
while SPY is `risk_on`, the rally is narrow, so lean toward the largest leaders and
size down.

## Exit management

1. The initial bracket stop and target are placed at entry.
2. At +1R, move the stop to breakeven (the entry price).
3. At +2R, trail at max(close − 2×ATR, SMA20 − 0.25×ATR). Raise it only after a daily close.
4. Exit early if the invalidation was hit, if there is thesis-breaking news, or if the
   regime turned `risk_off` and the position is below +1R.
5. Time stop: if the trade has not reached +1R by `max_hold_days`, close it, because
   the capital is better used elsewhere.
6. Never let a trade that reached +2R turn into a loss.

## Checklist before every entry

- [ ] Regime allows this setup and the score is at or above the regime minimum
- [ ] No earnings in the next 5 trading days, and no unexplained gap
- [ ] Bull case and bear case are both written down, and the invalidation is defined
- [ ] Reward/risk ≥ 2, the stop is between 0.5% and 12% away, and `risk.py` approves
- [ ] Not already holding the name, and there is room under the exposure and position-count caps
- [ ] The trade is logged in the journal with its thesis
