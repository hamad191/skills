---
name: stock-trading-agent
description: Multi-agent AI paper-trading desk for US stocks on Alpaca, with a Manager who sets the daily mandate and approves trades, Analysts who hunt for and prove high-expectancy setups, and a Trader who executes only approved orders. Use when the user wants to analyze US stocks or ETFs, find trade setups, read the market regime, size positions, place or manage paper trades, backtest a strategy, or review their trading journal. Triggers on "trade", "stock", "buy/sell signal", "paper trading", "Alpaca", "backtest", "portfolio", "تداول", "أسهم", "سهم", "صفقة". Paper trading only; it never places live orders.
---

# Stock Trading Desk (US equities, paper only)

This skill runs a small **trading desk** of AI agents with separate jobs, so no
single agent can both get excited about an idea and spend money on it:

| Role        | Job                                                                                       | Can place orders? |
| ----------- | ----------------------------------------------------------------------------------------- | ----------------- |
| **Manager** | Reads the regime, sets the day's mandate, challenges and approves ideas, sizes by conviction, learns from the journal | No                |
| **Analyst** (one or more) | Hunts for the highest-expectancy setups, proves them with backtests and research, proposes entries and profit-protecting stop raises and exits | No                |
| **Trader**  | Executes **only approved** proposals, with good timing and no chasing, then verifies fills | Yes, approved only |

They coordinate through `scripts/desk.py`, an append-only board where
analysts propose, the manager approves, and the trader executes. The separation
is enforced in code:

- The trader cannot execute anything unapproved or expired.
- The manager can scale a position down but never above `risk.py`.
- Stops can only move up.
- An entry is refused if the price has run more than 1% past the plan.

**You (the agent that loaded this skill) are the Manager.**

## Non-negotiable rules

- **Paper trading only.** `scripts/alpaca.py` is hard-wired to
  `paper-api.alpaca.markets` and refuses live keys. Never help work around this,
  never write code that calls the live endpoint, and never suggest the user do so.
- **Every entry has a stop-loss**, risking at most 1% of equity (`risk.py`). Never
  widen a stop. Never average down. If `risk.py` or the desk refuses something,
  it does not happen. Do not loosen limits to make a trade fit.
- **Long only**: no shorting, options, margin or leverage. No stocks under $5.
- **Honesty.** Never promise returns or call a trade "safe". This is educational
  paper trading, not financial advice. Report losses as plainly as wins.
- **Reply in the user's language** (for example Arabic). Keep tickers, numbers and
  commands as they are.

## Setup

Scripts are in `scripts/` next to this file and need only Python 3.9+. Below,
`S` is the **absolute** path to that directory. Always pass it to sub-agents.

```bash
# Free paper account: https://app.alpaca.markets/paper/dashboard/overview
export APCA_API_KEY_ID="PK..."        # paper key IDs start with PK
export APCA_API_SECRET_KEY="..."
python3 $S/alpaca.py account
```

Optional: `TRADING_JOURNAL`, `TRADING_DESK` (state files, by default under
`~/.trading-agent/`) and `TRADING_RISK_CONFIG` (stricter limits; see
`references/risk-management.md`). Without keys you can still analyze and backtest
CSV files with `--csv`.

## How to run the team

**If your host can spawn sub-agents** (for example Claude Code's Agent/Task tool),
run each analyst and the trader as a separate sub-agent:

- **Analysts:** give each one the full contents of `roles/analyst.md`, the absolute
  `S`, a unique analyst name, and its slice of the universe. Run 2 or 3 analysts in
  parallel on different sectors, and run one on open positions.
- **Trader:** give it the full contents of `roles/trader.md`, `S`, and the approved
  IDs, after your approvals.
- In Claude Code you can also install them permanently as sub-agents with
  `cp roles/analyst.md roles/trader.md .claude/agents/`.

**If you cannot spawn sub-agents**, play the roles one after another. Finish each
role completely and write its output to the desk before switching. Never skip the
desk: even as a single agent, entries go `propose`, then `approve`, then `execute`.

For a quick question ("analyze AAPL", "backtest breakouts on NVDA"), just run
`analyze.py` or `backtest.py` directly. The desk is for actually trading.

## The daily cycle (manager's view)

Follow `roles/manager.md` for the details. In short:

1. **Preflight.** `alpaca.py clock`, `account` and `positions`, then
   `desk.py board` and `journal.py review`. Act on the journal's flags and its
   `by_analyst` record.
2. **Mandate.** Run `analyze.py SPY QQQ IWM --regime-only` and a sector scan, then
   `desk.py set-mandate ...`. The mandate sets exposure, allowed setups, minimum
   score, the number of new entries and the risk scale. No mandate means no entry
   approvals.
3. **Dispatch analysts.** They return proposal IDs with thesis, bull and bear
   cases, invalidation and backtested expected R.
4. **Investment committee.** Use `desk.py board` and `show`. Challenge each idea,
   then `approve --size <conviction> --notes ...` or `reject --reason ...`. When
   ideas exceed the budget, fund the highest expected R first.
5. **Dispatch the trader.** It runs `desk.py execute` and verifies that each fill
   has a live stop leg.
6. **Manage positions.** Daily, the positions analyst proposes stop raises (+1R
   moves the stop to breakeven, +2R starts a trail) and exits (invalidation hit,
   time stop, regime change). You approve, and the trader executes.
7. **Report and learn.** Report to the user. Weekly, run `journal.py review`, pause
   losing setups, re-weight analysts, and record `journal.py lesson` entries.

Doing nothing is a valid and frequent decision. Most days the best trade is no trade.

## Command reference

| Script        | Purpose                                                                                     |
| ------------- | ------------------------------------------------------------------------------------------- |
| `desk.py`     | `set-mandate`, `mandate`, `propose`, `board`, `show`, `approve`, `reject`, `cancel`, `queue`, `execute`, `list` |
| `analyze.py`  | Indicators, 0–100 score, setups with entry/stop/target plans, market regime (`--rank --table`, `--regime-only`) |
| `backtest.py` | Walk-forward test of the same setups: expectancy in R, win rate, profit factor, drawdown     |
| `risk.py`     | Position sizing and hard limits (`--show-limits`, offline `--equity`)                       |
| `alpaca.py`   | Paper account: `clock`, `account`, `positions`, `orders`, `bars`, `snapshot`, plus `kill` (emergency) |
| `journal.py`  | Trade log and memory: `review` (by setup, confidence, regime, analyst), `lesson`, `skip`, `close` |

Every script has `--help`. Entries placed through the desk are journaled
automatically, tagged with the proposing analyst.

## Backtest before trusting a setup

```bash
python3 $S/backtest.py AAPL MSFT NVDA JPM XOM --benchmark SPY --days 2500
python3 $S/backtest.py --file bars.json --setup breakout --stop-atr 2.5 --target-r 3
```

The backtest has no look-ahead: it enters at the next open, assumes the stop
fills first when stop and target are hit on the same bar, and charges costs. Judge
`expectancy_r` (it must be above 0), `profit_factor` (above 1.3 is decent),
`trades` (30 or more), and `max_drawdown_pct`. When you tune parameters, validate
them on symbols you did not tune on. Never present backtest results as a forecast.

## Reporting a trade to the user

```
📈 AAPL: trend pullback (score 74/100, regime risk_on). Analyst: tech. Size 0.75
Entry ~190.20 | Stop 182.40 (-4.1%) | Target 209.70 (+10.3%) | R:R 2.5 | Backtest +0.31R/trade
Qty 57 = $10,841 (10.8% of equity), risk $445 (0.44%)
Bull: ... | Bear: ... | Invalidation: ...
Manager: approved because ...; sized down because ...
Status: paper bracket order submitted (id ...)
⚠️ Educational paper trading, not financial advice.
```

## Emergency stop

If the user says stop, panic, or close everything, if a position is reported
**UNPROTECTED**, or if anything looks broken:

```bash
python3 $S/alpaca.py kill    # cancels all orders and flattens all positions (paper)
```

## Files

- `roles/manager.md`, `roles/analyst.md`, `roles/trader.md`: the role playbooks (prompts for sub-agents)
- `references/strategy-playbook.md`: setups, scoring, regime logic, exit management
- `references/risk-management.md`: every risk limit and why it exists
- `references/universe.md`: default liquid watchlist and sector ETFs
