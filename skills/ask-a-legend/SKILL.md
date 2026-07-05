---
name: ask-a-legend
description: Get one legendary trader's read on a symbol — Wyckoff, Gann, Elliott Wave, Dow Theory, Livermore, DeMark, Wilder (RSI/ADX), Ichimoku (Hosoda), Weinstein stage analysis, or O'Neil CAN SLIM. Pass the legend and symbol, e.g. "gann on eurusd" or "what would Wyckoff say about AAPL?". Analysis and a second opinion, not a signal.
version: 0.1.0
author: FXDavid (Offbeat Forex)
license: MIT
homepage: https://github.com/FXDavid-OffbeatForex/TLC
platforms: [macos, linux, windows]
metadata:
  hermes:
    category: Finance
    tags: [trading, technical-analysis, market-analysis, forex, crypto, stocks, finance, wyckoff, gann]
    related_skills: [convene, forge-legend]
---
Run a single-legend analysis from **$ARGUMENTS** — a legend (name/nickname), a
symbol, and optionally a timeframe and platform (e.g. "gann eurusd 15m",
"what does Wyckoff think of BTCUSD?", "livermore on AAPL from tradingview").
Default timeframe is `1h` if omitted.

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
- **Both present → already configured. Continue to §1, and do NOT re-prompt for
  anything** (including a TV key): if TradingView is enabled but `.env` has no
  `TVR_API_KEY`, say so **once**, only the first time a TV symbol is actually
  requested — never nag it on every run.
- **Missing → this is first-run setup. Auto-configure. Do NOT run a question
  wizard, and never ask about "engine" or "alerts"** (Hermes runs the model and
  handles scheduling/delivery — those TLC settings don't apply here). Do this:

  **Setup gate — finish steps 2 and 3 before anything else.** After writing
  config, do NOT advance to §1, fetch data, run an analysis, or answer the legend
  request until setup is complete. Until then the only things you may emit are the
  MT5-terminal choice (step 2, when more than one terminal is running) or the
  TradingView-key prompt (step 3).

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
  continue to §1 (do not report a "config missing" failure — you just fixed it).

## 1. Resolve the legend id
Map the name/nickname in `$ARGUMENTS` to an id:

| Say any of… | id |
|---|---|
| Dow, Dow Theory | `dow` |
| Wyckoff | `wyckoff` |
| Livermore, Jesse Livermore | `livermore` |
| Elliott, Elliott Wave | `elliott` |
| Gann, W.D. Gann | `gann` |
| DeMark, Tom DeMark | `demark` |
| Wilder, Welles Wilder, RSI, ADX | `wilder` |
| Ichimoku, Hosoda | `hosoda` |
| Weinstein, Stan Weinstein, stage analysis | `weinstein` |
| O'Neil, CAN SLIM | `oneil` |

If the user names a **custom** legend they previously forged, its id is
whatever they gave it — its spec lives at `my_legends/<id>.md` (check there
first, then `tlc/legends/<id>.md`).

## 2. Run the single-legend flow
Follow `tlc/legends/_single_legend_flow.md` exactly, using that legend's spec
file as the method. Stay strictly in the legend's voice and method — if their
setup is absent, vote FLAT; never force a trade.

Platform (mt5 / TradingView) resolves per `AGENTS.md` §Platform resolution: a
trailing `tv`/`mt5` token or a phrase like "from tradingview" forces it,
otherwise it auto-routes by asset class, else falls back to `config.yaml`'s
default. Fetch bars with the registered MCP tool for that platform if one is
present in this Hermes environment, else the headless shortcut
`python3 -m tlc.data_desk <symbol> <tf> --platform <tv|mt5>`.

**Never fabricate market data.** If every fetch path fails (no MCP
registered, no API key, network error, timeout), **stop and report the
failure plainly** — which path you tried and why it failed. Do not estimate,
guess, or invent bars/prices/indicators to keep going. A wrong "I couldn't
get data" is safe; an invented ballot is not.

## 3. Present (mandatory — this is your final output)
**Do not stop after fetching data or writing an internal verification note.
Your final message to the user MUST be the analysis + ballot JSON below** — if
you've done the work but haven't shown it, you are not done. (On weaker models
it's easy to halt right before this step; don't.)

A short analysis in the legend's voice, then the ballot JSON block (direction,
conviction, entry, invalidation, target, thesis). This is one trader's read —
frame it as analysis and a second opinion, never as a signal or financial advice.
