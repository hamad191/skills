# Default Universe

These are liquid US large caps and ETFs, with tight spreads and deep volume. Use the
user's own watchlist when they give one. Re-check the list from time to time, because
index membership changes.

## Benchmarks and regime

`SPY` (S&P 500), `QQQ` (Nasdaq 100), `IWM` (Russell 2000), `DIA` (Dow 30)

## Sector ETFs (find the leading sectors first)

| Sector                 | ETF    | Sector            | ETF    |
| ---------------------- | ------ | ----------------- | ------ |
| Technology             | `XLK`  | Health care       | `XLV`  |
| Communication services | `XLC`  | Financials        | `XLF`  |
| Consumer discretionary | `XLY`  | Industrials       | `XLI`  |
| Consumer staples       | `XLP`  | Energy            | `XLE`  |
| Utilities              | `XLU`  | Materials         | `XLB`  |
| Real estate            | `XLRE` | Semiconductors    | `SMH`  |

```bash
python3 $S/analyze.py XLK XLC XLY XLP XLU XLRE XLV XLF XLI XLE XLB SMH --benchmark SPY --rank --table
```

## Large-cap watchlist by sector

- **Technology:** AAPL MSFT NVDA AVGO ORCL CRM ADBE AMD QCOM TXN INTU NOW AMAT MU PANW
- **Communication:** GOOGL META NFLX TMUS DIS
- **Consumer discretionary:** AMZN TSLA HD MCD LOW BKNG TJX NKE SBUX
- **Consumer staples:** WMT COST PG KO PEP PM
- **Health care:** LLY UNH JNJ ABBV MRK TMO ABT ISRG AMGN
- **Financials:** JPM V MA BAC WFC GS MS BLK AXP SPGI
- **Industrials:** GE CAT RTX HON UNP DE LMT BA ETN
- **Energy:** XOM CVX COP EOG SLB
- **Utilities and real estate:** NEE SO DUK PLD AMT
- **Materials:** LIN SHW FCX

Scan in batches of about 15 to 25 symbols. One `analyze.py` call fetches all of them
in a single request:

```bash
python3 $S/analyze.py AAPL MSFT NVDA AVGO ORCL CRM AMD GOOGL META AMZN TSLA LLY JPM V MA XOM --benchmark SPY --rank --top 8 --table
```
