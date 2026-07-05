---
name: forge-legend
description: Author a new trading legend/persona from a famous trader's name or a plain-English strategy description, then lint and live-audition it before it joins your roster. E.g. "make a trader who buys liquidity sweeps" or "add an ICT legend".
version: 0.1.0
author: FXDavid (Offbeat Forex)
license: MIT
homepage: https://github.com/FXDavid-OffbeatForex/TLC
platforms: [macos, linux, windows]
metadata:
  hermes:
    category: Finance
    tags: [trading, trading-strategy, technical-analysis, custom-indicator, backtesting, finance]
    related_skills: [convene, ask-a-legend]
---
Forge a new legend from **$ARGUMENTS** and admit it to the user's roster. Works
on a named figure or a plain-English strategy (e.g. "make a trader who buys
liquidity sweeps"). **Infer-first**: draft everything you can, ask only for
true gaps.

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
- **Read and write this skill's files in `terminal` too** — the draft spec at
  `my_legends/<id>.md`, temp `ballot.json`, `config.yaml`/`.env`. Every path here
  is relative to `$TLC_HOME`; if you use any other tool for a file, give it the
  **absolute** path under `$TLC_HOME`, or the next terminal command won't find it.
- **The fetched OHLCV packet is your only market-data source.** Never substitute
  a price or quote from web search, a browser, or any other tool — that is a
  subtler form of fabricating data.

## 0b. First-run setup (auto-configure — runs ONLY when config is missing)
Still inside `$TLC_HOME`, check for config: `ls .env config.yaml 2>/dev/null`.
- **Both present → already configured. Continue, and do NOT re-prompt for
  anything** (including a TV key): if TradingView is enabled but `.env` has no
  `TVR_API_KEY`, say so **once**, only the first time you audition on a TV symbol
  — never nag it on every run.
- **Missing → this is first-run setup. Auto-configure. Do NOT run a question
  wizard, and never ask about "engine" or "alerts"** (Hermes runs the model and
  handles scheduling/delivery — those TLC settings don't apply here). Do this:

  **Setup gate — finish steps 2 and 3 before anything else.** After writing
  config, do NOT start the audition, fetch data, or answer the request until setup
  is complete. Until then the only things you may emit are the MT5-terminal choice
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

  Never invent or hardcode a key; never put a real secret in `config.yaml`.

## 1. Classify the input
- A **named figure** (e.g. "ICT", "Al Brooks", "Minervini") → use the
  documented **public methodology**. Frame it as a *strategy profile*, not an
  impersonation of a person.
- A **strategy description** (including the user's own) → encode exactly what
  they wrote.

## 2. Draft the spec (format = `tlc/legends/<id>.md`)
Pick a lowercase `id` (letters/digits/underscore; don't collide with a core
legend unless the user wants to override one). Write frontmatter (`id,
display_name, tf_scope, default_anchor, regime_strengths`) + sections:
**Identity, Method, Timeframe rules, Vote rules, Output** (copy the shape of
`tlc/legends/wyckoff.md`). The Vote rules MUST state LONG/SHORT/FLAT
conditions, an **invalidation rule** (what proves it wrong — this becomes the
stop), and the **conviction** drivers. Output section points at
`tlc/legends/_single_legend_flow.md`.

## 3. Fill only the gaps
Ask the user **only** for fields you genuinely cannot infer — most often the
invalidation rule. Keep it to one or two short questions; infer the rest.

## 4. Lint (hard gate)
Write the draft to `my_legends/<id>.md`, then:
`python3 -m tlc.spec_lint my_legends/<id>.md`
If it reports errors, fix them and re-lint until clean. A spec with no
invalidation rule cannot pass — that's intentional (it must be scoreable).

## 5. Audition (live smoke-test)
Run the legend once via `tlc/legends/_single_legend_flow.md` on a sensible
symbol/timeframe for its method (resolve the platform per `AGENTS.md`).

**Never fabricate market data.** If every fetch path fails (no MCP
registered, no API key, network error, timeout), **stop and report the
failure plainly** rather than inventing bars/prices to complete the
audition — a fabricated smoke-test proves nothing.

Validate the resulting ballot:
`python3 -c "from tlc.ballot import validate_ballot; import json,sys; print(validate_ballot(json.load(sys.stdin)) or 'OK')" < ballot.json`
It must return `OK` (a schema-valid LONG/SHORT/FLAT ballot). If invalid, adjust
the spec and repeat. Optionally show a quick read of how it voted.

## 6. Save + offer to group (mandatory — this is your final output)
**Do not stop after linting or auditioning without telling the user the outcome.
Your final message MUST confirm whether the legend was admitted (or why it
wasn't) and offer the council step below** — if you've done the work but haven't
reported it, you are not done.

The spec is already at `my_legends/<id>.md` (gitignored — the user's edge
stays theirs). Confirm it's admitted, then offer to add it to a council: "Add
`<id>` to a council? (new one, or an existing roster)". Create/append rosters
with `python3 -m tlc.council new <name> <id…>`.
