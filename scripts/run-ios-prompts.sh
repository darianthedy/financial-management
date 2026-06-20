#!/usr/bin/env bash
#
# run-ios-prompts.sh — drive the iOS build prompts (P01..P12) sequentially.
#
# For each prompt: a FRESH `claude -p` session implements that one slice on a
# branch, the branch is merged to `main`, and we wait for the `iOS TestFlight`
# GitHub Action triggered by that merge. Green => advance to the next prompt.
# Red  => a fresh session opens a NEW fix branch, merges the fix, and we wait
#         for TestFlight again. Repeat until green (bounded by MAX_FIX_ATTEMPTS).
#
# WHY one session per prompt: the prompts doc requires it — a cold session
# re-reads the plan and keeps context tight; chaining slices in one session
# degrades quality.
#
# RUN THIS FROM A CLEAN, DEDICATED CHECKOUT ON `main` — NOT from a worktree you
# care about (it switches branches). Suggested:
#   git clone <repo> fm-pipeline && cd fm-pipeline && scripts/run-ios-prompts.sh
#
# Requires: claude CLI, gh (authed), git. macOS is NOT needed locally — the
# build happens on the GitHub macOS runner.

set -euo pipefail

# --- config -----------------------------------------------------------------
DOC="Financial Management - iOS Build Prompts.md"
WORKFLOW="ios-testflight.yml"
PROMPTS=(P01 P02 P03 P04 P05 P06 P07 P08 P09 P10 P11 P12)
MAX_FIX_ATTEMPTS=3
# Headless permissions. Sessions edit files + run git; for unattended runs this
# is the practical choice. Drop to --permission-mode acceptEdits to babysit.
CLAUDE_FLAGS=(--dangerously-skip-permissions)
START_AT="${1:-P01}"   # optional: resume, e.g. `scripts/run-ios-prompts.sh P05`

# --- helpers ----------------------------------------------------------------
log() { printf '\n\033[1;36m[%s] %s\033[0m\n' "$(date +%H:%M:%S)" "$*"; }
die() { printf '\n\033[1;31mABORT: %s\033[0m\n' "$*" >&2; exit 1; }

# Live-format Claude's stream-json events into readable lines, so a long session
# isn't a silent black box: prints assistant text + each tool call as it happens.
# No jq needed; falls back to raw passthrough if python3 is missing.
read -r -d '' STREAM_FMT <<'PYEOF' || true
import sys, json
def out(s):
    print(s); sys.stdout.flush()
for line in iter(sys.stdin.readline, ""):   # readline (not "for line in stdin") => no read-ahead buffering
    line = line.strip()
    if not line:
        continue
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

# Run a fresh headless Claude session with live, readable progress output.
# $1 = prompt. The pipeline's exit status is ignored on purpose — the real gate
# is "did the session commit?", checked by the caller.
#
# `< /dev/null` is REQUIRED: when claude -p's stdout is a pipe it assumes an
# `echo data | claude` pipeline and waits for stdin. Run interactively (TTY
# stdin) that wait never ends and the session hangs silently. /dev/null gives an
# immediate EOF so it proceeds.
run_claude() {
  local prompt="$1"
  if command -v python3 >/dev/null 2>&1; then
    claude -p "$prompt" "${CLAUDE_FLAGS[@]}" --output-format stream-json --verbose < /dev/null \
      | python3 -u -c "$STREAM_FMT" || true
  else
    claude -p "$prompt" "${CLAUDE_FLAGS[@]}" --output-format stream-json --verbose < /dev/null || true
  fi
}

# Implement a slice in a fresh session on a fresh branch off main, then merge.
# $1 = branch name   $2 = full prompt text for claude
# Returns the merge SHA in the global MERGE_SHA — NOT on stdout. (Using
# command substitution here would capture stdout and swallow all of the live
# session output, so the run would look silent.)
implement_and_merge() {
  local branch="$1" prompt="$2"
  git switch main >/dev/null
  git pull --ff-only origin main >/dev/null
  git switch -c "$branch" >/dev/null

  run_claude "$prompt"

  # Nothing committed => the session did no work; treat as failure.
  if git diff --quiet main HEAD; then
    die "$branch produced no commits"
  fi

  git push -u origin "$branch" >/dev/null
  gh pr create --base main --head "$branch" --fill >/dev/null
  gh pr merge "$branch" --merge --delete-branch >/dev/null
  git switch main >/dev/null
  git pull --ff-only origin main >/dev/null
  MERGE_SHA=$(git rev-parse HEAD)   # hand back via global so stdout stays free to stream
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

  log "=== $P : implementing ==="
  base_prompt="In this repo, read \"$DOC\", find prompt $P, and follow its \
**Run** line exactly — read the §refs it cites and implement ONLY the $P slice, \
no more, no less. Verify table/column/view/RPC names against supabase/migrations/. \
When finished, commit all changes with a clear message. Do not push or open a PR."

  implement_and_merge "ios/$P" "$base_prompt"; sha="$MERGE_SHA"

  attempt=0
  until wait_for_testflight "$sha"; do
    attempt=$((attempt+1))
    [ "$attempt" -gt "$MAX_FIX_ATTEMPTS" ] && die "$P: TestFlight still failing after $MAX_FIX_ATTEMPTS fixes"
    log "=== $P : TestFlight FAILED — fix attempt $attempt ==="
    run_id=$(gh run list --workflow "$WORKFLOW" --branch main \
              --json databaseId,headSha -L 30 \
              --jq "[.[] | select(.headSha==\"$sha\")][0].databaseId")
    fail_log=$(gh run view "$run_id" --log-failed 2>/dev/null | tail -150 || echo "(log unavailable)")
    fix_prompt="The iOS TestFlight build on \`main\` for prompt $P FAILED. \
Read \"$DOC\" prompt $P for the intended scope, then fix the build error below — \
change only what's needed to make \`fastlane beta\` (Release scheme \
FinancialManagement) compile and sign. Commit; do not push.

--- failing build log (tail) ---
$fail_log"
    implement_and_merge "ios/$P-fix$attempt" "$fix_prompt"; sha="$MERGE_SHA"
  done

  log "=== $P : TestFlight GREEN ✅ ==="
done

log "All prompts complete. 🎉"
