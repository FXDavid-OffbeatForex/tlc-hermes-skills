#!/usr/bin/env bash
# Bootstrap for TLC Hermes skills: clone/update the TA-Legends-Council engine
# and install its runtime deps into an isolated venv (avoids PEP 668
# "externally-managed-environment" failures on Debian/Ubuntu hosts).
# Idempotent — safe to run on every invocation. Prints the repo path on stdout.
set -euo pipefail

TLC_HOME="${TLC_HOME:-$HOME/.tlc/TA-Legends-Council}"
TLC_REPO="${TLC_REPO:-https://github.com/FXDavid-OffbeatForex/TLC.git}"

# Hermes runs this script inside an isolated sandboxed shell that doesn't
# share the interactive session's cached git credentials. Without this, a
# credential-less `git pull`/`clone` cascades through every interactive
# prompt fallback (GCM browser popup, git-askpass, /dev/tty) before finally
# failing — each one confusing on an attended run and pure dead time on an
# unattended cron fire, where nothing can ever complete the prompt. Forcing
# non-interactive mode makes an auth failure fail immediately and silently
# instead of stalling on prompts no one is there to answer.
export GIT_TERMINAL_PROMPT=0
export GCM_INTERACTIVE=never

# GitHub access can stall transiently (seen in testing: SYN/TLS hangs that
# clear up on retry). A single unbounded git call can eat the whole harness
# command timeout on one bad attempt — bound each try and retry instead.
git_retry() {
  local attempt
  for attempt in 1 2 3 4; do
    if timeout 30 git "$@"; then
      return 0
    fi
    echo "git $* failed (attempt $attempt/4), retrying..." >&2
    sleep 3
  done
  return 1
}

if [ -d "$TLC_HOME/.git" ]; then
  git_retry -C "$TLC_HOME" pull --ff-only -q || true
else
  mkdir -p "$(dirname "$TLC_HOME")"
  git_retry clone -q "$TLC_REPO" "$TLC_HOME"
fi

# Prefer python3, but fall back to python (Windows installs rarely ship a
# python3 shim, even under Git Bash).
PYTHON_BIN="python3"
command -v python3 >/dev/null 2>&1 || PYTHON_BIN="python"

VENV="$TLC_HOME/.venv"
# POSIX venvs put the interpreter at bin/python3; Windows-native venvs (incl.
# under Git Bash, since Python's venv module is Windows-native) use
# Scripts/python.exe instead.
if [ -x "$VENV/bin/python3" ]; then
  VENV_PY="$VENV/bin/python3"
elif [ -x "$VENV/Scripts/python.exe" ]; then
  VENV_PY="$VENV/Scripts/python.exe"
else
  VENV_PY=""
fi

if [ -z "$VENV_PY" ]; then
  "$PYTHON_BIN" -m venv "$VENV"
  if [ -x "$VENV/bin/python3" ]; then
    VENV_PY="$VENV/bin/python3"
  else
    VENV_PY="$VENV/Scripts/python.exe"
  fi
fi

"$VENV_PY" -m pip install -q --upgrade pip
"$VENV_PY" -m pip install -q -r "$TLC_HOME/requirements.txt"

echo "$TLC_HOME"
