---
name: convene
description: Convene the Trading Legends Council — ten legendary traders (Dow, Wyckoff, Livermore, Elliott, Gann, DeMark, Wilder, Ichimoku, Weinstein, O'Neil) each vote blind on a symbol, then a deterministic Chairman aggregates their ballots into one verdict (LONG/SHORT/NO_TRADE). Analysis and a second opinion, not signals.
version: 0.2.0
author: FXDavid (Offbeat Forex)
license: MIT
homepage: https://github.com/FXDavid-OffbeatForex/TLC
platforms: [macos, linux, windows]
metadata:
  hermes:
    category: Finance
    tags: [trading, technical-analysis, market-analysis, forex, crypto, stocks, finance, trading-signals]
    related_skills: [ask-a-legend, forge-legend]
---
Convene the **Trading Legends Council** on the symbol/timeframe/platform found in
**$ARGUMENTS** (e.g. "convene BTCUSD 1h", "what does the council think of AAPL?",
"convene the orderflow council on EURUSD"). Default timeframe is `1h` if omitted.

## 0. Bootstrap (every run — cheap and idempotent)
Run `scripts/setup.sh` (in this skill's own directory) and capture its stdout as `TLC_HOME`
(it clones/updates `github.com/FXDavid-OffbeatForex/TLC` under `~/.tlc/` and
installs `requirements.txt` into an isolated venv at `$TLC_HOME/.venv`).
`cd "$TLC_HOME"` and add the venv to PATH before every command below:
`export PATH="$TLC_HOME/.venv/bin:$TLC_HOME/.venv/Scripts:$PATH"` (POSIX
venvs use `bin`, Windows-native venvs use `Scripts` — only one will exist,
so prepending both is safe everywhere). This makes plain `python3` (or
`python` on Windows, which usually has no `python3` shim) resolve to the
venv with deps installed — **not** to any other Python that happens to be
on PATH (e.g. the harness's own bundled interpreter), which would silently
run against the wrong environment and fail with confusing import errors.
If the script fails, report the exact error — do not fall back to a
half-installed run.

**Do all of this skill's work in the `terminal` tool, inside `$TLC_HOME` —
never `execute_code` or any other code-sandbox tool for `tlc.*` commands.**
Those sandboxes are a separate, isolated Python environment without this
project's venv, `MetaTrader5`, or MBT's `core` module, so a `tlc.*` call there
fails with a misleading `ModuleNotFoundError`/`NotImplementedError`. Three rules
follow:
- **An import/`ModuleNotFoundError` is almost never a real data outage.** It
  means the wrong tool ran the command, or the venv/cwd from §0 didn't carry
  into this call. Re-assert `cd "$TLC_HOME"` + the PATH export in `terminal` and
  retry there. **Never** let such an error override data you already fetched
  successfully earlier in the same conversation — reuse that data, don't discard it.
- **Read and write this skill's files in `terminal` too** — temp `frames.json`/
  `packet.json`/`ballot.json`, spec files, `config.yaml`/`.env`. Every path here
  is relative to `$TLC_HOME`; if you use any other tool for a file, give it the
  **absolute** path under `$TLC_HOME`, or the next terminal command won't find it.
- **The fetched OHLCV packet is your only market-data source.** Never substitute
  a price or quote from web search, a browser, or any other tool — that is a
  subtler form of fabricating data.

## 0b. First-run setup (auto-configure — runs ONLY when config is missing)
Still inside `$TLC_HOME`, check for config: `ls .env config.yaml 2>/dev/null`.
- **Both present → already configured. Continue, and do NOT re-prompt for
  anything** (including a TV key): if TradingView is enabled but `.env` has no
  `TVR_API_KEY`, say so **once**, only the first time a TV symbol is actually
  requested — never nag it on every run.
- **Missing → this is first-run setup. Auto-configure. Do NOT run a question
  wizard, and never ask about "engine" or "alerts"** (Hermes runs the model and
  handles scheduling/delivery — those TLC settings don't apply here). Do this:

  **Setup gate — finish steps 2 and 3 before anything else.** After writing
  config, do NOT convene, fetch data, or answer the request until setup is
  complete. Until then the only things you may emit are the MT5-terminal choice
  (step 2, when more than one terminal is running) or the TradingView-key prompt
  (step 3).

  1. Write `config.yaml` from `config.example.yaml`: `enabled_platforms:
     [mt5, tradingview]`, `default_platform: mt5`, **no `bridge_url`** (Docker/
     remote only). Write a blank `.env` scaffold.
  2. **MT5 — the zero-config, no-key default.** MBT lives at `$TLC_HOME/MBT`
     (clone `github.com/FXDavid-OffbeatForex/MBT` there + `pip install -r
     MBT/requirements.txt` if absent); `tlc.providers.mt5` puts it on `sys.path`,
     so no bridge is needed. **Before any fetch, count the running MT5 terminals**
     (`Get-Process terminal64` on Windows / `pgrep -f terminal64` under Wine):
     - **exactly one →** `mt5.initialize()` auto-attaches; leave `mt5_path` blank.
     - **more than one → you MUST list them and ask the user which one**, then set
       `mt5_path` in `MBT/config.yaml` to their choice. **Never silently pick.**
     - **none running →** search `C:\Program Files\**\terminal64.exe` and confirm.
  3. **TradingView key — ask once here (first-run only, never again).** Tell the
     user TV is optional and needs a free key from tvremix.xyz (account → API
     keys), then let them add it now or skip:
     - **Desktop/local:** open `$TLC_HOME/.env` (`code .env` / reveal it) and have
       them paste it in a real editor and save — **key stays in the file, not chat.**
     - **Telegram/remote:** they send it; **save to `$TLC_HOME/.env` immediately
       (and delete their message if the channel supports it)**. Or **"skip"** —
       MT5 works with no key.
     If skipped, leave `TVR_API_KEY` blank; TradingView stays unavailable until
     someone adds it to `$TLC_HOME/.env` (it's one shared file — set once, works
     from every interface). **Do not re-ask on later runs.**

  Never invent or hardcode a key; never put a real secret in `config.yaml`. Then
  continue (do not report a "config missing" failure — you just fixed it).

## 0c. Open-trade gate (ONLY when the request asks for it)

TLC's own scheduler (`tlc.cron`) gates every fire so it alerts **one trade at a
time** — while the last signalled trade is still open (neither stop nor target
hit) it skips convening entirely (no LLM call, no re-alert), and emits a single
WIN/LOSS when it resolves. Hermes runs this convene as a raw prompt, which
bypasses that wrapper, so the gate must be invoked here — but **only for a
scheduled, gated run**, never for an ad-hoc "convene EURUSD".

**Trigger — gate this run if, and only if, `$ARGUMENTS` asks for it:** a `--gate`
token, or wording like "open-trade gate", "gated", "one trade at a time", "don't
re-alert while a trade is open". A Hermes cron prompt enables it explicitly, e.g.
*"every hour convene EURUSD 1h with the open-trade gate and send to Discord."*
If no such signal is present, **skip this whole section** and convene normally.

When gated, derive the stable schedule name (shared with `tlc.cron` state) and
run **phase 1 (check)** before doing any other work:
```bash
NAME=$(python3 -c "import sys;from tlc.cron import make_name;print(make_name(sys.argv[1],sys.argv[2]))" <SYMBOL> <TF>)
python3 -m tlc.trade_gate check "$NAME" <SYMBOL> <TF> [--platform tv|mt5]
```
Read its **last decision line**:
- **`SKIP …`** → the previous trade is still open (or a fire is in flight).
  **Stop here — do NOT build a packet, fetch data, convene, or alert.** If the
  output also has an `OUTCOME {…}` line, a trade just resolved: relay that
  win/loss to the user through the Hermes channel, then stop.
- **`PROCEED …`** → clear to convene. If an `OUTCOME {…}` line is present, the
  previous trade resolved this fire — **deliver that WIN/LOSS first** (it won't
  come through any other channel here), then continue to §1 and convene normally.

After you finish §3 (verdict aggregated + saved to `data/verdicts.jsonl`), run
**phase 2 (record)** so the new signal becomes the tracked open trade:
```bash
python3 -m tlc.trade_gate record "$NAME" <SYMBOL> <TF> [--platform tv|mt5]
```
A LONG/SHORT verdict is now tracked; the next gated fire will skip until it
resolves. A NO_TRADE verdict tracks nothing (the gate stays open). Run `record`
even if the verdict was NO_TRADE — it advances the checkpoint.

## 1. Build the market packet (once, shared by all legends — fairness)
- Parse intent + normalize the symbol/timeframe (see `tlc/normalize.py`).
- **Resolve the platform** (explicit `tv`/`mt5` token in `$ARGUMENTS` → asset-class
  auto-route → `config.yaml` default; see `AGENTS.md` §Platform resolution) and the
  native symbol.
- Pull bars for the frames `15m, 1h, 4h, 1d` (≈200 bars each):
  - **mt5** → the registered MCP tool for MT5 bars (MBT's `get_ohlcv`), if
    registered in this Hermes environment; else `python3 -m tlc.data_desk <symbol> <tf> --platform mt5`.
  - **tradingview** → the registered MCP tool for TradingView bars (tvremix's
    `get_ohlcv`), if registered; else the headless shortcut:
    `python3 -m tlc.data_desk <symbol> <tf> --platform tv` (needs `TVR_API_KEY`
    in `.env` — see §0 of `AGENTS.md`).
- **Never fabricate market data.** If every fetch path fails (no MCP
  registered, no API key, network error, timeout), **stop and report the
  failure plainly** — which path you tried and why it failed. Do not
  estimate, guess, or invent bars/prices/indicators to keep going. A wrong
  "I couldn't get data" is safe; an invented ballot is not.
- Build the packet (this also computes ATR per timeframe and tags `platform`):
  write `{platform, symbol, anchor_timeframe, frames}` to a temp JSON and run
  `python3 -m tlc.market_packet <frames.json> <packet.json>`.
  Every legend MUST receive this identical packet — no legend gets extra data.
- **Deterministic indicators are per-legend, not shared.** Any legend whose spec
  declares `needs:` computes its own exact readings in its blind step (see
  `tlc/legends/_single_legend_flow.md` §3b: `python3 -m tlc.indicators <packet.json> --needs …`).
  Keep them out of the shared packet so no legend sees another school's numbers.

## 2. Determine the council, then collect ballots (BLIND, in parallel)
Pick the roster:
- **Default** (no council named): the canonical 10 — dow, wyckoff, livermore,
  elliott, gann, demark, wilder, hosoda, weinstein, oneil.
- **Custom** (NL "convene the NAME council"): resolve members with
  `python3 -m tlc.council show NAME` — each member's spec path is
  `my_legends/<id>.md` first, then `tlc/legends/<id>.md`.

For each member, run the single-legend flow (`tlc/legends/_single_legend_flow.md`)
against the **same packet**, using that legend's spec. Each returns one ballot JSON.

Legends vote **independently** — do not let one legend see another's vote.

## 3. Validate, persist, aggregate
- Validate each ballot (`tlc.ballot.validate_ballot`); drop invalid ones, noting why.
- Save all ballots to the local sink (`data/ballots.jsonl`).
- Run the Chairman to produce the verdict. Use the council's threshold/weights for
  a custom roster (`tlc.council.council_settings`); default threshold is `0.65`.
  Write the ballots to a JSON array and run
  `python3 -m tlc.run_council <ballots.json> --alert`, or call
  `tlc.chairman.aggregate(ballots, threshold=…, weights=…)` directly.
- **If this is a gated run (§0c), you MUST use `run_council` (not a direct
  `aggregate()` call)** — it persists the verdict to `data/verdicts.jsonl`, which
  is exactly where `record` looks; a verdict that never lands there arms nothing
  and the gate silently stops gating. Then run the `record` phase so this verdict
  arms/clears the tracked open trade.
- **About `--alert`:** it pushes the verdict through TLC's own alert channels
  (`alerts.enabled` in `$TLC_HOME/config.yaml`, e.g. Telegram) — the same path
  scheduled fires use. It is a no-op when no channel is configured there (the
  Hermes auto-setup in §0b never enables one — Hermes normally delivers through
  its own channel instead), and NO_TRADE respects `quiet_no_trade`, so passing it
  unconditionally is safe and keeps alerting identical across harnesses for users
  who DID configure TLC alerts in the shared `~/.tlc` config.

## 4. Present (mandatory — this is your final output)
**Do not stop after collecting ballots, aggregating, or writing an internal
verification note. Your final message to the user MUST be the ballot table +
Chairman's verdict below** — if you've done the work but haven't shown it, you
are not done. (On weaker models it's easy to halt right before this step; don't.)

Show a table of the ballots (legend · direction · conviction · entry · stop ·
target · one-line thesis), then the **Chairman's verdict**: decision (LONG /
SHORT / **NO_TRADE**), consensus %, entry, stop, target, R:R, and which legends
were for / against / abstaining. Remember: a split council is NO_TRADE — standing
aside is a valid, often correct, outcome.

This is analysis and a second opinion — never present it as a signal or financial
advice.
