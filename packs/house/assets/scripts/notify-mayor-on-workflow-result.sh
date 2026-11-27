#!/usr/bin/env bash
# notify-mayor-on-workflow-result: mail the mayor when a workflow run
# finishes, or when one of its reviews ends without approval.
#
# Nothing in gascity tells the coordinator a run is done. A build records its
# result on the workflow root bead (gc.outcome, gc.build.*_status) and stops;
# convoy.notify is stored but never sent. So the mayor finds out only when a
# person asks, a finished run's slot sits idle, and a PR whose review ran out
# of rounds looks exactly like one that passed.
#
# Each run of this order scans every rig's top-level workflow roots
# (gc.kind=workflow, no gc.source_anchor_id, so per-item child workflows are
# skipped) and derives notice keys:
#
#   closed:<outcome>        the run's root closed
#   plan-review:<status>    gc.build.plan_review_status left the normal states
#   code-review:<status>    gc.build.code_review_status left the normal states
#
# Normal review states are empty, draft, ready, pending, running,
# in_progress and approved. Anything else (failed, changes_required,
# blocked...) is worth telling the mayor while the run is still going,
# because a build does not stop when a review loop runs out of rounds.
#
# Every new key is mailed once with `gc mail send --notify`, which wakes the
# mayor even when its session is stopped. The mail states the facts only;
# what to do about them is the mayor's judgment.
#
# It reads the bead store, not the event log: a run's head can close without
# emitting bead.closed, and an exec order on an event trigger re-fires on its
# own tracking beads. Hence a cooldown trigger.
#
# State: $GC_PACK_STATE_DIR/notify-mayor-on-workflow-result-state.json. The
# first run seeds it with every current key and sends nothing, so installing
# the order does not replay old runs. A failed send is not recorded and the
# script exits non-zero, so the controller logs it and the next run retries.
#
# Environment (all optional):
#   GC_WORKFLOW_NOTICE_TO        recipient; default: the session whose
#                                template is <binding>.mayor, else "mayor"
#   GC_WORKFLOW_NOTICE_LOOKBACK  closed runs to consider, in hours (default 6)
#   GC_WORKFLOW_NOTICE_DRY_RUN   1 = print notices instead of sending them
#                                and leave the state file untouched
set -uo pipefail

if ! command -v jq >/dev/null 2>&1; then
    echo "notify-mayor-on-workflow-result: jq is required but not found in PATH" >&2
    exit 1
fi

CITY="${GC_CITY:-${GC_CITY_PATH:-.}}"
cd "$CITY" || { echo "notify-mayor-on-workflow-result: cannot cd to $CITY" >&2; exit 1; }

LOOKBACK_HOURS="${GC_WORKFLOW_NOTICE_LOOKBACK:-6}"
DRY_RUN="${GC_WORKFLOW_NOTICE_DRY_RUN:-0}"
# State entries not seen for this long are pruned. Must exceed the lookback.
RETENTION_SECS=$(( (LOOKBACK_HOURS + 24) * 3600 ))

PACK_STATE_DIR="${GC_PACK_STATE_DIR:-${GC_CITY_RUNTIME_DIR:-$CITY/.gc/runtime}/packs/house}"
STATE_FILE="$PACK_STATE_DIR/notify-mayor-on-workflow-result-state.json"
mkdir -p "$PACK_STATE_DIR"

NOW="$(date -u +%s)"
SINCE="$(date -u -d "-${LOOKBACK_HOURS} hours" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
    || date -u -v-"${LOOKBACK_HOURS}"H +%Y-%m-%dT%H:%M:%SZ)"

SEEDING=0
if [ -s "$STATE_FILE" ] && jq -e . "$STATE_FILE" >/dev/null 2>&1; then
    STATE="$(cat "$STATE_FILE")"
else
    SEEDING=1
    STATE='{"runs":{}}'
fi

# ── recipient ───────────────────────────────────────────────────────────
TO="${GC_WORKFLOW_NOTICE_TO:-}"
if [ -z "$TO" ]; then
    TO="$(gc session list --json 2>/dev/null \
        | jq -r '(if type == "array" then . else (.sessions // .items // []) end)[]
                 | select(((.template // "") | test("(^|\\.)mayor$")))
                 | (.alias // .name // .template)' 2>/dev/null | head -1)"
    [ -n "$TO" ] || TO="mayor"
fi

# ── scopes: every rig, plus the city store ─────────────────────────────
# Each line: <rig name or empty for the city store><TAB><path>
SCOPES="$(gc rig list --json 2>/dev/null \
    | jq -r '(.rigs // [])[] | [(if .hq == true then "" else .name end), .path] | @tsv' 2>/dev/null)"
[ -n "$SCOPES" ] || SCOPES="$(printf '\t%s' "$CITY")"

bd_in() {
    # bd_in <rig> <args...>: gc bd scoped to a rig, or the city store.
    local rig="$1"; shift
    if [ -n "$rig" ]; then gc bd --rig "$rig" "$@"; else gc bd "$@"; fi
}

first_bead() {
    # gc bd show --json returns an object or a one-element array.
    jq -c 'if type == "array" then .[0] else . end'
}

FAILED=0
SENT=0

# Bead lists run to hundreds of KB (each carries its formula description), too
# big for a command-line argument, so they go through files.
TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT

list_to() {
    # list_to <file> <rig> <bd list args...>: a JSON array, or [] on failure.
    local out="$1"; shift
    bd_in "$@" 2>/dev/null >"$out" || true
    jq -e 'type == "array"' "$out" >/dev/null 2>&1 || echo '[]' >"$out"
}

while IFS=$'\t' read -r RIG RIG_PATH; do
    [ -n "$RIG_PATH" ] || RIG_PATH="$CITY"

    list_to "$TMPD/open.json" "$RIG" list --metadata-field gc.kind=workflow \
        --status open,in_progress,blocked --limit 0 --json
    list_to "$TMPD/closed.json" "$RIG" list --all --metadata-field gc.kind=workflow \
        --closed-after "$SINCE" --limit 0 --json

    # One compact line per top-level root, with its notice keys.
    ROOTS="$(jq -c -s '
        def normal: . as $s | ["", "draft", "ready", "pending", "running", "in_progress", "approved", "reported"] | index($s);
        add
        | unique_by(.id)[]
        | select(((.metadata // {})["gc.source_anchor_id"] // "") == "")
        | (.metadata // {}) as $m
        | {
            id, title, status,
            m: $m,
            keys: (
              [ (($m["gc.build.plan_review_status"] // "") | select(normal | not) | "plan-review:" + .),
                (($m["gc.build.code_review_status"] // "") | select(normal | not) | "code-review:" + .),
                (if .status == "closed" then "closed:" + ($m["gc.outcome"] // "unknown") else empty end)
              ]
            )
          }' "$TMPD/open.json" "$TMPD/closed.json" 2>/dev/null)" || ROOTS=""

    while IFS= read -r ROOT; do
        [ -n "$ROOT" ] || continue
        ID="$(jq -r .id <<<"$ROOT")"
        STATE_KEY="${RIG:-city}/$ID"
        CUR_KEYS="$(jq -c '.keys' <<<"$ROOT")"
        OLD_KEYS="$(jq -c --arg k "$STATE_KEY" '.runs[$k].keys // []' <<<"$STATE")"
        NEW_KEYS="$(jq -c -n --argjson c "$CUR_KEYS" --argjson o "$OLD_KEYS" '$c - $o')"

        if [ "$NEW_KEYS" = "[]" ] || [ "$SEEDING" = 1 ]; then
            STATE="$(jq -c --arg k "$STATE_KEY" --argjson c "$CUR_KEYS" --argjson o "$OLD_KEYS" --argjson now "$NOW" \
                '.runs[$k] = {keys: ($o + $c | unique), seen: $now}' <<<"$STATE")"
            continue
        fi

        # ── gather what the notice reports ────────────────────────────
        M="$(jq -c .m <<<"$ROOT")"
        mget() { jq -r --arg k "$1" '.[$k] // ""' <<<"$M"; }
        FORMULA="$(mget gc.formula_name)"
        STATUS="$(jq -r .status <<<"$ROOT")"
        OUTCOME="$(mget gc.outcome)"
        PLAN="$(mget gc.build.plan_review_status)"
        CODE="$(mget gc.build.code_review_status)"
        PUBLISH="$(mget gc.build.publish_status)"
        ART_ROOT="$(mget gc.var.artifact_root)"

        CHILDREN="$(bd_in "$RIG" list --all --limit 0 \
            --metadata-field "gc.root_bead_id=$ID" --json 2>/dev/null)" || CHILDREN='[]'
        [ -n "$CHILDREN" ] || CHILDREN='[]'

        # Review rounds: highest iteration of each "Synthesize ... review" step.
        ROUNDS="$(jq -r '
            [ .[] | select(.title | test("^Synthesize .*review"; "i"))
              | { kind: (.title | ascii_downcase | capture("(?<k>plan|code|starter) review").k // "review"),
                  it: (((.metadata // {})["gc.iteration"] // "1") | tonumber? // 1) } ]
            | group_by(.kind)[] | "\(.[0].kind)=\(map(.it) | max)"' <<<"$CHILDREN" 2>/dev/null)"
        round_of() { sed -n "s/^$1=//p" <<<"$ROUNDS" | head -1; }

        # Review verdicts, for formulas that keep them on steps (build-basic).
        VERDICTS="$(jq -r '
            [ .[] | select(.title | test("^Finalize .*review"; "i"))
              | select(.title | test("^Finalize scope for"; "i") | not)
              | select((.metadata // {})["gc.max_attempts"] != null)
              | "\(.title): \((.metadata // {})["gc.outcome"] // .status)" ] | unique[]' <<<"$CHILDREN" 2>/dev/null)"

        # PR link: on the root, on a publish step, or in the publish artifact.
        PR_URL="$(mget gc.pr_url)"
        if [ -z "$PR_URL" ]; then
            PR_URL="$(jq -r '[.[] | (.metadata // {})["gc.pr_url"] // empty] | last // ""' <<<"$CHILDREN" 2>/dev/null)"
        fi
        if [ -z "$PR_URL" ]; then
            PUB_ART="$(mget gc.build.publish_artifact_path)"
            case "$PUB_ART" in ""|/*) ;; *) PUB_ART="$RIG_PATH/$PUB_ART" ;; esac
            if [ -n "$PUB_ART" ] && [ -r "$PUB_ART" ]; then
                PR_URL="$(grep -oE 'https://github\.com/[^ )>`"]+/pull/[0-9]+' "$PUB_ART" | tail -1)"
            fi
        fi

        # Source bead: the input convoy is titled "input convoy for <bead>".
        SOURCE=""
        CONVOY="$(mget gc.var.convoy_id)"
        if [ -n "$CONVOY" ]; then
            SOURCE="$(bd_in "$RIG" show "$CONVOY" --json 2>/dev/null | first_bead \
                | jq -r '.title // "" | capture("^input convoy for (?<b>\\S+)").b // ""' 2>/dev/null)"
        fi
        if [ -z "$SOURCE" ]; then
            SOURCE="$(sed -nE 's#.*gc-plans/([^/]+)/.*#\1#p' <<<"$ART_ROOT")"
        fi
        SOURCE_TITLE=""
        if [ -n "$SOURCE" ]; then
            SOURCE_TITLE="$(bd_in "$RIG" show "$SOURCE" --json 2>/dev/null | first_bead | jq -r '.title // ""' 2>/dev/null)"
        fi

        # ── compose ───────────────────────────────────────────────────
        # The review verdict leads the subject. gc.outcome is not a reliable
        # signal: some formulas mark a run "fail" although every review
        # approved it, and publish a PR although a review ran out of rounds.
        review_state() {
            # review_state <status>: done-ok | unfinished | bad
            case "$1" in
                approved|reported) echo done-ok ;;
                ""|draft|ready|pending|running|in_progress) echo unfinished ;;
                *) echo bad ;;
            esac
        }
        P_STATE="$(review_state "$PLAN")"
        C_STATE="$(review_state "$CODE")"
        if [ "$P_STATE" = bad ] || [ "$C_STATE" = bad ]; then
            REVIEW="review NOT approved"
        elif [ -n "$VERDICTS" ] && grep -q ': fail$' <<<"$VERDICTS"; then
            REVIEW="review NOT approved"
        elif [ "$C_STATE" = done-ok ] \
             || { [ -z "$PLAN$CODE" ] && [ -n "$VERDICTS" ] && ! grep -qv ': pass$' <<<"$VERDICTS"; }; then
            REVIEW="review approved"
        else
            REVIEW="review not finished"
        fi

        LABEL="${SOURCE:-$ID} ${FORMULA:-workflow}"
        PR_PART="no PR"
        [ -n "$PR_URL" ] && PR_PART="PR #${PR_URL##*/}"
        if jq -e 'any(startswith("closed:"))' <<<"$NEW_KEYS" >/dev/null; then
            SUBJECT="Run finished: $LABEL, $REVIEW, $PR_PART"
            [ "$OUTCOME" = pass ] || SUBJECT="$SUBJECT (run outcome: ${OUTCOME:-none})"
        else
            WHAT="$(jq -r 'map(select(startswith("closed:") | not)) | map(sub(":"; " ")) | join(", ")' <<<"$NEW_KEYS")"
            SUBJECT="Review NOT approved, run still going: $LABEL ($WHAT)"
        fi

        review_line() {
            # review_line <label> <status> <round kind>
            local s="$2" r; r="$(round_of "$3")"
            [ -n "$s$r" ] || return 0
            local mark=""
            case "$(review_state "$s")" in
                bad) mark="   <-- NOT approved" ;;
                unfinished) [ -n "$s" ] && mark="   (not finished)" ;;
            esac
            if [ -n "$s" ]; then
                printf '%-14s%s%s%s\n' "$1:" "$s" "${r:+ after $r round(s)}" "$mark"
            else
                printf '%-14s%s round(s); verdict in the review steps below\n' "$1:" "$r"
            fi
        }

        BODY="$(
            echo "Workflow notice. These are facts read from the run's beads; check them before acting. What to do is your call."
            echo
            echo "Run:          $ID (${FORMULA:-unknown formula}), status $STATUS${OUTCOME:+, outcome $OUTCOME}"
            echo "Source bead:  ${SOURCE:-unknown}${SOURCE_TITLE:+ - $SOURCE_TITLE}"
            echo "Rig:          ${RIG:-city}"
            echo "New:          $(jq -r 'join(", ")' <<<"$NEW_KEYS")"
            review_line "Plan review" "$PLAN" plan
            review_line "Code review" "$CODE" code
            review_line "Review" "" starter
            if [ -n "$VERDICTS" ]; then
                echo "Review steps:"
                sed 's/^/  /' <<<"$VERDICTS"
            fi
            [ -n "$PUBLISH" ] && echo "Publish:      $PUBLISH"
            echo "PR:           ${PR_URL:-none found}"
            [ -n "$ART_ROOT" ] && echo "Artifacts:    $ART_ROOT"
        )"

        DEDUP="workflow-notice:${RIG:-city}:$ID:$(jq -r 'join(",")' <<<"$NEW_KEYS")"
        if [ "$DRY_RUN" = 1 ]; then
            printf -- '--- to %s (dedup %s)\nSubject: %s\n%s\n\n' "$TO" "$DEDUP" "$SUBJECT" "$BODY"
            continue
        fi
        if gc mail send "$TO" --notify --dedup "$DEDUP" -s "$SUBJECT" -m "$BODY" >/dev/null; then
            SENT=$((SENT + 1))
            STATE="$(jq -c --arg k "$STATE_KEY" --argjson c "$CUR_KEYS" --argjson o "$OLD_KEYS" --argjson now "$NOW" \
                '.runs[$k] = {keys: ($o + $c | unique), seen: $now}' <<<"$STATE")"
        else
            echo "notify-mayor-on-workflow-result: could not mail $TO about $ID ($SUBJECT)" >&2
            FAILED=1
        fi
    done <<<"$ROOTS"
done <<<"$SCOPES"

[ "$DRY_RUN" = 1 ] && exit 0

# Prune runs not seen within the retention window, then save atomically.
STATE="$(jq -c --argjson now "$NOW" --argjson keep "$RETENTION_SECS" \
    '.runs |= with_entries(select(($now - (.value.seen // 0)) < $keep))' <<<"$STATE")"
TMP="$(mktemp "$STATE_FILE.XXXXXX")"
printf '%s\n' "$STATE" >"$TMP" && mv -f "$TMP" "$STATE_FILE"

if [ "$SEEDING" = 1 ]; then
    echo "notify-mayor-on-workflow-result: seeded state with $(jq '.runs | length' <<<"$STATE") runs; nothing sent"
elif [ "$SENT" -gt 0 ]; then
    echo "notify-mayor-on-workflow-result: sent $SENT notice(s) to $TO"
fi
exit "$FAILED"
