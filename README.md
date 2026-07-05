<h1 align="center">🏛️ Trading Legends Council — Hermes Agent skills</h1>

<p align="center">
  <em>Ten legendary traders analyze any chart. One verdict.</em>
</p>

<p align="center">
  <img alt="License: MIT" src="https://img.shields.io/badge/License-MIT-3ddc84.svg">
  <img alt="Hermes Agent" src="https://img.shields.io/badge/Hermes-Agent-8a63d2">
  <img alt="Skills" src="https://img.shields.io/badge/skills-3-1f6feb">
  <img alt="Not financial advice" src="https://img.shields.io/badge/⚠-not%20financial%20advice-f0883e">
</p>

Three [Hermes Agent](https://hermes-agent.nousresearch.com) skills that run the
[**Trading Legends Council (TLC)**](https://github.com/FXDavid-OffbeatForex/TLC) —
ten schools of technical analysis (Wyckoff, Gann, Elliott, Dow, Livermore,
DeMark, Wilder, Ichimoku, Weinstein, O'Neil) each voting **blind** on a chart,
then a deterministic Chairman aggregating the ballots into a single call.

| Skill | What it does |
|---|---|
| **`/convene`** | The full 10-legend council on a symbol → one Chairman verdict (LONG / SHORT / NO_TRADE) |
| **`/ask-a-legend`** | A single legend's read — *"gann on eurusd"*, *"what would Wyckoff say about AAPL?"* |
| **`/forge-legend`** | Author your own legend from a name or a plain-English strategy, then lint + live-audition it |

Each skill **self-bootstraps** — it clones the open-source TLC engine and builds
an isolated Python venv on first run — so the only thing you install is this
small skills folder.

## Example

```
> /convene EURUSD 1h

Legend      Dir    Conv   Thesis
─────────────────────────────────────────────────────────
Wyckoff     FLAT   0.00   No spring/upthrust; range-bound
Gann        LONG   0.55   Above 1x1 angle off the swing low
Dow         FLAT   0.00   Lower highs unconfirmed
…
─────────────────────────────────────────────────────────
CHAIRMAN VERDICT:  NO_TRADE   (consensus 41% < 65% threshold)
A split council stands aside — that is a valid outcome.
```
*Illustrative — TLC runs on live data you fetch; it never invents prices.*

## Requirements

- **git** + **Python 3** on your PATH — the skill clones TLC and installs its
  deps. On Windows, install [git-scm.com](https://git-scm.com) and
  [python.org](https://python.org) (tick *"Add Python to PATH"*).
- **[Hermes Agent](https://hermes-agent.nousresearch.com)** — CLI or Desktop.
- Market data (either works):
  - **MT5 / MetaTrader** — forex & metals, **zero config, no key** (needs the MT5
    terminal installed + logged into a broker).
  - **TradingView** — stocks & crypto, via a free key from
    [tvremix.xyz](https://tvremix.xyz).

## Install

**From the Hermes Hub — one command each:**

```bash
hermes skills install FXDavid-OffbeatForex/tlc-hermes-skills/convene --yes
hermes skills install FXDavid-OffbeatForex/tlc-hermes-skills/ask-a-legend --yes
hermes skills install FXDavid-OffbeatForex/tlc-hermes-skills/forge-legend --yes
```

That's it — `hermes skills list` should now show all three. (They're
community skills that clone the open-source TLC engine + `pip install` its one
dependency on first run; Hermes shows a standard third-party-skill review
prompt — `--yes` accepts it.)

### Alternative — local, via `external_dirs`

If you'd rather run them straight from a clone (e.g. to hack on them):

```bash
git clone https://github.com/FXDavid-OffbeatForex/tlc-hermes-skills.git
```

Point Hermes at the `skills/` folder — add to `~/.hermes/config.yaml`
(or `%LOCALAPPDATA%\hermes\config.yaml` on native Windows):

```yaml
skills:
  external_dirs:
    - /absolute/path/to/tlc-hermes-skills/skills
```

Restart Hermes — `hermes skills list` should show all three.

## Usage

```
/convene EURUSD 1h
/ask-a-legend gann on eurusd
/forge-legend make a trader who buys liquidity sweeps
```

First run configures itself automatically — MT5 is the zero-config default; it
asks once for a TradingView key if you want stocks or crypto.

## How it works

The skill is deliberately tiny: a `SKILL.md` (instructions) + a `setup.sh` that
clones the [TLC engine](https://github.com/FXDavid-OffbeatForex/TLC) into
`~/.tlc/` and builds an isolated venv. Every run does a fast `git pull`, so the
council logic stays current without ever re-installing the skill. The ten
legends vote **blind** on an identical market packet, and a deterministic
Chairman — not the LLM — aggregates the ballots, so a split council correctly
returns **NO_TRADE**.

> **⚠️ Not financial advice.** TLC is analysis and a second opinion — ten schools
> of technical analysis reasoning over a chart. It is never a signal to act on,
> and it never fabricates data: if it can't fetch real bars, it says so.

## Links

- **TLC engine** — https://github.com/FXDavid-OffbeatForex/TLC
- **Hermes Agent** — https://hermes-agent.nousresearch.com

## License

[MIT](LICENSE) · built by [FXDavid / Offbeat Forex](https://github.com/FXDavid-OffbeatForex)
