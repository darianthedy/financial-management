#!/usr/bin/env bash
#
# run-design-parity-prompts.sh — drive the iOS↔web design-parity prompts
# (Prompt 1..8 in iOS/design-parity-prompts.md) sequentially, one fresh Claude
# session per prompt.
#
# For each prompt: a FRESH `claude -p` session implements that one prompt on a
# branch, the branch is merged to `main`, and we wait for the `iOS TestFlight`
# GitHub Action triggered by that merge. Green => advance to the next prompt.
# Red  => a fresh session opens a NEW fix branch, merges the fix, and we wait
#         for TestFlight again. Repeat until green (bounded by MAX_FIX_ATTEMPTS).
#
# WHY one session per prompt: the prompts doc is built so each prompt is fully
# self-contained and meant to run in its own session — a cold session re-reads
# the shared context and keeps focus tight; chaining prompts in one session
# degrades quality.
#
# SHARED CONTEXT: every session is fed the doc's "## Shared context" section
# (web is the source of truth, token paths, verification standard, iOS app root)
# prepended to that prompt's own text, so the shared context travels with each
# prompt exactly as the doc intends.
#
# RUN THIS FROM A CLEAN, DEDICATED CHECKOUT ON `main` — NOT from a worktree you
# care about (it switches branches). Suggested:
#   git clone <repo> fm-parity && cd fm-parity && scripts/run-design-parity-prompts.sh
#
# Requires: claude CLI, gh (authed), git, python3. macOS is NOT needed locally —
# the build happens on the GitHub macOS runner.
#
# Unattended-friendly: each prompt auto-cleans a stale branch first, and if a
# session is aborted by the Claude usage limit the driver sleeps until the
# window resets, then RESUMES that same Claude session (--resume) with a
# "continue where you left off" nudge so it finishes — its context and the files
# already written on the branch are preserved, not redone. Keep the terminal
# alive (tmux/nohup) since the wait can be hours. To resume after fully stopping,
# pass the prompt to restart at: `scripts/run-design-parity-prompts.sh P5`.

set -euo pipefail

# --- config -----------------------------------------------------------------
DOC="iOS/design-parity-prompts.md"
WORKFLOW="ios-testflight.yml"
PROMPTS=(P1 P2 P3 P4 P5 P6 P7 P8)   # maps to "## Prompt 1".."## Prompt 8"
MAX_FIX_ATTEMPTS=3
# Headless permissions. Sessions edit files + run git; for unattended runs this
# is the practical choice. Drop to --permission-mode acceptEdits to babysit.
CLAUDE_FLAGS=(--dangerously-skip-permissions)
START_AT="${1:-P1}"   # optional: resume, e.g. `scripts/run-design-parity-prompts.sh P5`
# Before each prompt, probe the Claude usage tier; if it isn't "allowed" (i.e.
# already at/near the limit) wait for the reset instead of starting — so we don't
# burn a prompt that would abort partway. Set 0 to disable. NOTE: the headless
# CLI exposes only a status tier + resetsAt, not a numeric %, so this fires on
# Claude's own near/at-limit signal, not a settable 90% line.
PREFLIGHT_USAGE_GATE="${PREFLIGHT_USAGE_GATE:-1}"

[ -f "$DOC" ] || { printf 'ABORT: run from the repo root; "%s" not found here.\n' "$DOC" >&2; exit 1; }

# --- helpers ----------------------------------------------------------------
log() { printf '\n\033[1;36m[%s] %s\033[0m\n' "$(date +%H:%M:%S)" "$*"; }
die() { printf '\n\033[1;31mABORT: %s\033[0m\n' "$*" >&2; exit 1; }
trap '[ -n "${RAW_LOG:-}" ] && rm -f "$RAW_LOG" 2>/dev/null' EXIT

# Build the full prompt text for one design-parity prompt: the doc's shared
# context section + that prompt's fenced code block + a commit instruction.
# $1 = prompt number (e.g. "5"). Echoes the assembled prompt on stdout.
build_prompt() {
  python3 - "$DOC" "$1" <<'PY'
import sys, re
doc = open(sys.argv[1], encoding="utf-8").read()
n = sys.argv[2]

# "## Shared context ..." heading -> the bullet list, up to the next "---".
m = re.search(r"##\s*Shared context.*?\n(.*?)\n---", doc, re.S)
shared = (m.group(1).strip() if m else "")

# "## Prompt N — ..." -> the first fenced ``` ... ``` block under it.
m = re.search(r"##\s*Prompt\s+%s\b.*?\n```[a-zA-Z]*\n(.*?)\n```" % re.escape(n), doc, re.S)
if not m:
    sys.exit("prompt %s not found in %s" % (n, sys.argv[1]))
prompt = m.group(1).strip()

print("SHARED CONTEXT — applies to every iOS design-parity prompt:")
print()
print(shared)
print()
print("=" * 70)
print()
print("TASK — iOS Design Parity, Prompt %s:" % n)
print()
print(prompt)
print()
print("=" * 70)
print()
print("Stay strictly within this prompt's scope — do NOT do other prompts' work. "
      "NEVER modify anything under web/. When finished, commit ALL your changes "
      "with a clear message. Do NOT push or open a PR — the driver script does that.")
PY
}

# Live-format Claude's stream-json events into readable lines, so a long session
# isn't a silent black box: prints assistant text + each tool call as it happens.
# No jq needed; falls back to raw passthrough if python3 is missing.
read -r -d '' STREAM_FMT <<'PYEOF' || true
import sys, json, os
def out(s):
    print(s); sys.stdout.flush()
# Keep a raw copy of the stream so the driver can tell a usage-limit abort
# (wait + retry) from a genuine failure (stop).
_raw = open(os.environ["RAW_LOG"], "a", encoding="utf-8") if os.environ.get("RAW_LOG") else None
for line in iter(sys.stdin.readline, ""):   # readline (not "for line in stdin") => no read-ahead buffering
    line = line.strip()
    if not line:
        continue
    if _raw:
        _raw.write(line + "\n"); _raw.flush()
    try:
        ev = json.loads(line)
    except Exception:
        out(line); continue
    t = ev.get("type")
    if t == "system" and ev.get("subtype") == "init":
        out("  ▶ session started (model %s, perms %s)"
            % (ev.get("model", "?"), ev.get("permissionMode", "?")))
    elif t == "assistant":
        for b in ev.get("message", {}).get("content", []):
            bt = b.get("type")
            if bt == "text" and b.get("text", "").strip():
                out(b["text"].rstrip())
            elif bt == "thinking" and b.get("thinking", "").strip():
                out("  \U0001f4ad " + b["thinking"].strip().replace("\n", " ")[:140])
            elif bt == "tool_use":
                inp = b.get("input", {}) or {}
                hint = (inp.get("command") or inp.get("file_path")
                        or inp.get("pattern") or inp.get("description") or "")
                hint = str(hint).replace("\n", " ")
                if len(hint) > 100:
                    hint = hint[:100] + "…"
                out("  \U0001f527 %s: %s" % (b.get("name", "?"), hint))
    elif t == "result":
        if ev.get("is_error"):
            out("  ⚠️  result error: %s — %s"
                % (ev.get("subtype", ""), str(ev.get("result", ""))[:200]))
        else:
            out("  ✓ session done")
PYEOF

# Run a fresh (or resumed) headless Claude session with live progress output.
# $1 = prompt, $2 = fresh|resume. The pipeline's exit status is ignored on
# purpose — the real gate is "did the session commit?", checked by the caller.
#
# `< /dev/null` is REQUIRED: when claude -p's stdout is a pipe it assumes an
# `echo data | claude` pipeline and waits for stdin. /dev/null gives an immediate
# EOF so it proceeds instead of hanging silently.
run_claude() {
  local prompt="$1" mode="${2:-fresh}"
  [ -n "${RAW_LOG:-}" ] && rm -f "$RAW_LOG"
  RAW_LOG=$(mktemp)   # raw stream for usage-limit detection (see rate_limit_wake)
  local -a cmd=(claude)
  if [ "$mode" = resume ]; then
    cmd+=(--resume "$SESSION_ID")     # continue the interrupted session WITH its context + work so far
  else
    SESSION_ID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || python3 -c 'import uuid;print(uuid.uuid4())')
    cmd+=(--session-id "$SESSION_ID") # assign a known id up front so we can resume it after a limit
  fi
  cmd+=(-p "$prompt" "${CLAUDE_FLAGS[@]}" --output-format stream-json --verbose)
  if command -v python3 >/dev/null 2>&1; then
    "${cmd[@]}" < /dev/null | RAW_LOG="$RAW_LOG" python3 -u -c "$STREAM_FMT" || true
  else
    "${cmd[@]}" < /dev/null | tee "$RAW_LOG" || true
  fi
  read_usage "$RAW_LOG"   # keep the freshest usage signal for the next pre-flight
}

# If the most recent session aborted because of the Claude usage limit, echo the
# epoch second to wake at (the rate_limit_event's resetsAt + 60s buffer; falls
# back to now + 5h). Echoes nothing if the abort wasn't a usage limit — so the
# caller can tell "wait and retry" from "genuine failure, stop".
rate_limit_wake() {
  [ -f "${RAW_LOG:-}" ] || return 0
  python3 - "$RAW_LOG" <<'PY'
import sys, json, re, time
limited = False; reset = 0
# Anchored to the CLI's actual limit phrasing so app code that merely mentions
# "limit" won't false-trigger.
pat = re.compile(r"hit your (?:session|usage) limit|(?:session|usage) limit\b.{0,40}reset|usage limit reached|rate.?limit reached|\b429\b", re.I)
try:
    for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
        line = line.strip()
        if not line:
            continue
        if pat.search(line):           # matches the limit message wherever it appears
            limited = True
        try:
            ev = json.loads(line)
        except Exception:
            continue
        if ev.get("type") == "rate_limit_event":
            info = ev.get("rate_limit_info", {}) or {}
            if str(info.get("status", "")).lower() not in ("", "allowed"):
                limited = True
            if info.get("resetsAt"):
                reset = max(reset, int(info["resetsAt"]))
except FileNotFoundError:
    pass
if limited:
    print(reset + 60 if reset else int(time.time()) + 5 * 3600 + 60)
PY
}

# Delete a leftover branch (local + remote) and close any open PR for it, so a
# resumed or retried prompt can recreate it cleanly. No-op if nothing exists.
cleanup_branch() {
  local branch="$1" pr
  git switch main >/dev/null 2>&1 || true
  git branch -D "$branch" >/dev/null 2>&1 || true
  git push origin --delete "$branch" >/dev/null 2>&1 || true
  pr=$(gh pr list --head "$branch" --state open --json number -q '.[0].number' 2>/dev/null || true)
  [ -n "$pr" ] && gh pr close "$pr" >/dev/null 2>&1 || true
  return 0
}

# Parse a raw stream log into the usage globals: USAGE_STATUS (the last
# rate_limit_event's status, or "none" if absent) and USAGE_RESET (its resetsAt
# epoch, or 0). Lets the driver gate on the freshest signal it has.
read_usage() {
  local f="$1"
  USAGE_STATUS="none"; USAGE_RESET=0
  [ -f "$f" ] || return 0
  read -r USAGE_STATUS USAGE_RESET < <(python3 - "$f" <<'PY'
import sys, json, re
status = ""; reset = 0; limited = False
pat = re.compile(r"hit your (?:session|usage) limit|(?:session|usage) limit\b.{0,40}reset|usage limit reached|rate.?limit reached|\b429\b", re.I)
try:
    for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
        line = line.strip()
        if not line:
            continue
        if pat.search(line):
            limited = True
        try:
            ev = json.loads(line)
        except Exception:
            continue
        if ev.get("type") == "rate_limit_event":
            info = ev.get("rate_limit_info", {}) or {}
            if info.get("status"):
                status = str(info["status"])
            if info.get("resetsAt"):
                reset = int(info["resetsAt"])
except FileNotFoundError:
    pass
# A limit message anywhere => treat as a limit tier so pre-flight waits.
if limited and status in ("", "none", "allowed"):
    status = "rejected"
print(status or "none", reset)
PY
)
  : "${USAGE_STATUS:=none}" "${USAGE_RESET:=0}"
}

# Probe current usage with a minimal session, into the usage globals.
probe_usage() {
  local f; f=$(mktemp)
  claude -p "ok" "${CLAUDE_FLAGS[@]}" --output-format stream-json --verbose < /dev/null >"$f" 2>/dev/null || true
  read_usage "$f"; rm -f "$f"
}

# Before starting a prompt: if usage is already at a limit tier (status not
# "allowed"/"none"), sleep until the reset rather than starting work. Re-probes
# after each wait. Capped so an odd status can't loop forever.
preflight_wait() {
  [ "$PREFLIGHT_USAGE_GATE" = 1 ] || return 0
  local waits=0 now secs
  [ -n "${USAGE_STATUS:-}" ] || probe_usage      # first prompt: no prior signal yet
  while [ "${USAGE_STATUS:-none}" != "allowed" ] && [ "${USAGE_STATUS:-none}" != "none" ]; do
    waits=$((waits+1)); [ "$waits" -gt 6 ] && die "usage still limited ('$USAGE_STATUS') after 6 pre-flight waits"
    now=$(date +%s); secs=$(( USAGE_RESET - now )); [ "$secs" -lt 60 ] && secs=60
    log "Pre-flight: usage tier '$USAGE_STATUS' (at/near limit) — not starting; sleeping ~$((secs/60)) min until $(date -d "@$USAGE_RESET" '+%a %H:%M') reset…"
    sleep "$secs"
    probe_usage
  done
}

# Implement a prompt in a fresh session on a fresh branch off main, then merge.
# $1 = branch name   $2 = full prompt text for claude
# Returns the merge SHA in the global MERGE_SHA — NOT on stdout. (Command
# substitution here would capture stdout and swallow all the live session
# output, so the run would look silent.)
implement_and_merge() {
  local branch="$1" prompt="$2" waits=0 wake now secs
  cleanup_branch "$branch"                                   # clear any stale branch/PR (resume/retry)
  git switch main >/dev/null            || die "switch main failed"
  git pull --ff-only origin main >/dev/null || die "pull main failed"
  git switch -c "$branch" >/dev/null    || die "create $branch failed"

  run_claude "$prompt" fresh

  # No commit => the session didn't finish. If it was a usage-limit abort, wait
  # for the reset and RESUME the same session — its context and the files it
  # already wrote on this branch are preserved, so it continues instead of
  # starting over. Anything else is a genuine failure.
  while git diff --quiet main HEAD; do
    wake=$(rate_limit_wake)
    [ -n "$wake" ] || die "$branch produced no commits"
    waits=$((waits+1)); [ "$waits" -gt 6 ] && die "$branch: still usage-limited after 6 resumes"
    now=$(date +%s); secs=$(( wake - now )); [ "$secs" -lt 60 ] && secs=60
    log "Usage limit mid-session. Sleeping ~$((secs/60)) min until $(date -d "@$wake" '+%a %H:%M'), then RESUMING session ${SESSION_ID:0:8} (keeping work so far)…"
    sleep "$secs"
    run_claude "continue" resume
  done

  git push -u origin "$branch" >/dev/null   || die "push $branch failed"
  gh pr create --base main --head "$branch" --fill >/dev/null || die "pr create failed"
  gh pr merge "$branch" --merge --delete-branch >/dev/null    || die "pr merge failed"
  git switch main >/dev/null            || die "switch main failed"
  git pull --ff-only origin main >/dev/null || die "pull main failed"
  MERGE_SHA=$(git rev-parse HEAD)   # hand back via global so stdout stays free to stream
  return 0
}

# Run one prompt. Pre-flight-gates on usage, then implements + merges. A
# usage-limit hit mid-session is waited out and the session is RESUMED inside
# implement_and_merge (work preserved). Sets MERGE_SHA on success.
do_prompt() {
  preflight_wait                 # don't even start if usage is already at the limit tier
  implement_and_merge "$1" "$2"  # handles mid-session usage-limit waits + resume internally
}

# Block until the TestFlight run for a given commit SHA finishes.
# Returns 0 on success, 1 on failure.
wait_for_testflight() {
  local sha="$1" id="" tries=0
  log "Waiting for $WORKFLOW run on ${sha:0:8} ..."
  # The run can take a moment to register after the push.
  while [ -z "$id" ]; do
    id=$(gh run list --workflow "$WORKFLOW" --branch main \
          --json databaseId,headSha -L 30 \
          --jq "[.[] | select(.headSha==\"$sha\")][0].databaseId" 2>/dev/null || true)
    [ -n "$id" ] && break
    tries=$((tries+1)); [ "$tries" -gt 40 ] && die "no TestFlight run appeared for ${sha:0:8}"
    sleep 15
  done
  gh run watch "$id" --exit-status --interval 30
}

# --- main loop --------------------------------------------------------------
started=0
for P in "${PROMPTS[@]}"; do
  [ "$P" = "$START_AT" ] && started=1
  [ "$started" = 1 ] || { log "skip $P (resuming at $START_AT)"; continue; }

  num="${P#P}"   # "P5" -> "5"
  log "=== $P : implementing (design parity prompt $num) ==="
  prompt_text=$(build_prompt "$num") || die "could not build prompt $num from $DOC"

  do_prompt "design-parity/$P" "$prompt_text"; sha="$MERGE_SHA"

  attempt=0
  until wait_for_testflight "$sha"; do
    attempt=$((attempt+1))
    [ "$attempt" -gt "$MAX_FIX_ATTEMPTS" ] && die "$P: TestFlight still failing after $MAX_FIX_ATTEMPTS fixes"
    log "=== $P : TestFlight FAILED — fix attempt $attempt ==="
    run_id=$(gh run list --workflow "$WORKFLOW" --branch main \
              --json databaseId,headSha -L 30 \
              --jq "[.[] | select(.headSha==\"$sha\")][0].databaseId")
    fail_log=$(gh run view "$run_id" --log-failed 2>/dev/null | tail -150 || echo "(log unavailable)")
    fix_prompt="The iOS TestFlight build on \`main\` for design-parity Prompt $num FAILED. \
The intended scope of that prompt is below, followed by the failing build log. \
Fix the build error — change only what's needed to make \`fastlane beta\` (Release \
scheme FinancialManagement) compile and sign. NEVER modify anything under web/. \
Commit all changes with a clear message; do NOT push or open a PR.

--- design-parity Prompt $num (intended scope) ---
$prompt_text

--- failing build log (tail) ---
$fail_log"
    do_prompt "design-parity/$P-fix$attempt" "$fix_prompt"; sha="$MERGE_SHA"
  done

  log "=== $P : TestFlight GREEN ✅ ==="
done

log "All design-parity prompts complete. 🎉"
