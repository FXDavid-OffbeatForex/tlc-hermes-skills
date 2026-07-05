# TLC — Hermes Agent skills

Three skills that run the [Trading Legends Council](https://github.com/FXDavid-OffbeatForex/TLC)
inside [Hermes Agent](https://hermes-agent.nousresearch.com):

- **convene** — the full 10-legend council on a symbol → one Chairman verdict
- **ask-a-legend** — a single legend's read (Wyckoff, Gann, Elliott, Dow, …)
- **forge-legend** — author your own legend, then lint + live-audition it

Each skill **self-bootstraps TLC** — it clones the TLC repo and builds an
isolated Python venv on first run — so the only thing you install is this small
skills folder.

## Requirements

- **git** and **Python 3** on your PATH (the skill clones TLC + installs its
  deps). Windows: install from [git-scm.com](https://git-scm.com) and
  [python.org](https://python.org) (tick *"Add Python to PATH"*).
- **Hermes Agent** (CLI or Desktop).
- Market data — either works:
  - **MT5 / MetaTrader** (forex, metals) — **zero config, no key** (needs the
    MT5 terminal installed + logged into a broker).
  - **TradingView** (stocks, crypto) — a free key from
    [tvremix.xyz](https://tvremix.xyz).

## Install (local skills — no Hub needed)

1. Clone this repo:
   ```
   git clone https://github.com/FXDavid-OffbeatForex/tlc-hermes-skills.git
   ```
2. Point Hermes at the `skills/` folder — add to `~/.hermes/config.yaml`
   (or `%LOCALAPPDATA%\hermes\config.yaml` on native Windows):
   ```yaml
   skills:
     external_dirs:
       - /absolute/path/to/tlc-hermes-skills/skills
   ```
3. Restart Hermes. `hermes skills list` should show `convene`, `ask-a-legend`,
   and `forge-legend`.

### …or just ask Hermes (one paste)

> Clone `github.com/FXDavid-OffbeatForex/tlc-hermes-skills`, add its `skills`
> folder to my Hermes `external_dirs`, then convene EURUSD.

## Usage

```
/convene EURUSD 1h
/ask-a-legend gann on eurusd
/forge-legend make a trader who buys liquidity sweeps
```

On first run the skill sets itself up automatically (MT5 is the zero-config
default; it asks once for a TradingView key if you want stocks/crypto).

> **Not financial advice.** TLC is analysis and a second opinion — ten schools
> of technical analysis voting on a chart, never a signal to act on.

## License

MIT — see [LICENSE](LICENSE). The TLC engine lives at
[FXDavid-OffbeatForex/TLC](https://github.com/FXDavid-OffbeatForex/TLC).
