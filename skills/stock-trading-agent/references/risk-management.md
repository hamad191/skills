# Risk Management

Risk rules are enforced in code by `scripts/risk.py`. `alpaca.py buy` and
`desk.py execute` call it before every order and refuse anything it rejects;
`desk.py approve` runs the same check (plus the sector cap) before the manager's
approval is recorded. The manager's `--size` and the mandate's `--risk-scale`
can only shrink the size `risk.py` allows, never grow it.

## Limits

| Key                      | Default | Hard cap      | Why                                                                     |
| ------------------------ | ------- | ------------- | ----------------------------------------------------------------------- |
| `risk_per_trade_pct`     | 1.0     | ≤ 2.0         | Ten losers in a row cost about 10%, which is survivable. Ruin is the only unrecoverable outcome. |
| `max_position_pct`       | 15      | ≤ 25          | No single name can sink the account on an overnight gap.               |
| `max_gross_exposure_pct` | 90      | ≤ 100         | No margin. Also capped by the regime (`--max-exposure`).               |
| `max_open_positions`     | 8       | ≤ 20          | Keeps attention per position high and limits correlated bets.          |
| `max_daily_loss_pct`     | 3.0     | ≤ 5.0         | Stops revenge trading. Once hit, no new entries for the rest of the day. |
| `min_reward_risk`        | 2.0     | ≥ 1.0         | With 2R targets, a 35% win rate still breaks even.                     |
| `min_price`              | 5.0     | ≥ 1.0         | Avoids penny stocks, wide spreads and manipulation.                    |
| `max_stop_distance_pct`  | 12      | none          | A wider stop means the setup is too loose or the stock too volatile.   |
| `min_stop_distance_pct`  | 0.5     | none          | Tighter stops get hit by normal noise.                                 |

## Position sizing

```
shares = min(
  floor(equity × risk_per_trade% ÷ (entry − stop)),     # equal risk per trade
  floor(equity × max_position% ÷ entry),                # concentration cap
  floor(remaining exposure room ÷ entry),               # regime / gross cap
  floor(min(buying_power, equity) ÷ entry)              # never use margin
)
```

The output shows which limit was binding (`binding_limit`). A volatile stock
automatically gets fewer shares, because a wider stop leaves fewer shares for the
same dollar risk.

## Configuring

You can make limits stricter with a JSON file:

```json
{ "risk_per_trade_pct": 0.5, "max_open_positions": 5, "max_daily_loss_pct": 2 }
```

```bash
export TRADING_RISK_CONFIG=~/.trading-agent/risk.json
python3 scripts/risk.py --show-limits
```

Values looser than the hard caps are clamped to the caps. Unknown keys are ignored.

## Behavioral rules the code cannot enforce (you must)

- Never widen a stop or remove one. Stops only move up.
- Never add to a losing position. `risk.py` rejects a second entry in a symbol you
  already hold.
- After 3 consecutive losses, use `risk_per_trade_pct: 0.5` until the next winner.
- After a −3% day, stop opening trades. Review the journal tomorrow instead.
- Correlation: no more than 3 positions in one sector (`desk.py approve` enforces this
  for symbols in the default universe and for proposals tagged `--sector`). Five
  semiconductor stocks are one bet, not five.
- Overnight and earnings gaps can jump past stops. That is why there is a
  position-size cap and an earnings blackout.
