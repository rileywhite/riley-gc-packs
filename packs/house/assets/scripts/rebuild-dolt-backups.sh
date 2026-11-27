#!/usr/bin/env bash
# rebuild-dolt-backups: replace each bead scope's Dolt backup with a fresh
# copy, so the backups stop growing.
#
# The dolt pack's mol-dog-backup order runs `bd backup sync` every few hours
# into a file:// mirror (by default <city>/.dolt-backup/<db>). A sync only ever
# adds storage files to that mirror. When the live database is compacted, the
# history it drops stays in the backup, still listed in the backup's manifest,
# so Dolt's own --prune-with-grace-period (which only removes unreferenced
# files) cannot reclaim it. Left alone the mirror grows without limit: on
# cilador-city the city backup reached 7.0 GB for an ~800 MB database and
# the rig backup 1.4 GB for one that rebuilt to 101 MB.
#
# For every scope (the city store and each rig) whose backup destination is a
# file:// URL, this script:
#
#   1. syncs the live database into a new directory next to the backup
#      (CALL dolt_backup('sync-url', ...) through the dolt client);
#   2. verifies the new copy: `dolt backup restore` into a scratch directory,
#      `dolt fsck`, the issues table reads, and the restored head commit is
#      present in the live database's history;
#   3. only then swaps it in and deletes the old backup.
#
# If any step fails, the old backup stays exactly where it was, the partial
# copy is removed, and the mayor is mailed with --notify. A scope that has
# no backup destination yet, or one that is not file://, is skipped:
# mol-dog-backup creates destinations, and a remote destination is the
# remote's business.
#
# It holds the same flock as mol-dog-backup (backup-sync.lock), so the two
# never write to a backup at the same time. Leftovers from an interrupted run
# are cleaned up first: a backup that was moved aside but not replaced is put
# back, and an unfinished copy is deleted.
#
# Environment (all optional):
#   GC_BACKUP_REBUILD_DRY_RUN        1 = report what would be rebuilt, change
#                                    nothing
#   GC_BACKUP_REBUILD_SYNC_TIMEOUT_SECS  bound for one full sync (default 1800)
#   GC_BACKUP_REBUILD_LOCK_WAIT_SECS     how long to wait for the backup lock
#                                    (default 900)
#   GC_BACKUP_REBUILD_NOTIFY_TO      who is mailed on failure; default: the
#                                    session whose template is <binding>.mayor
#   GC_DOLT_BACKUP_LOCK_FILE         the lock mol-dog-backup uses (default
#                                    <city>/.gc/runtime/packs/dolt/backup-sync.lock)
#   GC_DOLT_HOST, GC_DOLT_PORT, GC_DOLT_USER, GC_DOLT_PASSWORD
#                                    the Dolt server, as for the dolt pack
#                                    (port default: its dolt-state.json)
set -uo pipefail

NAME="rebuild-dolt-backups"

for tool in jq dolt flock; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "$NAME: $tool is required but not found in PATH" >&2
        exit 1
    fi
done

CITY="${GC_CITY:-${GC_CITY_PATH:-.}}"
cd "$CITY" || { echo "$NAME: cannot cd to $CITY" >&2; exit 1; }
CITY_ABS="$(pwd -P)"

DRY_RUN="${GC_BACKUP_REBUILD_DRY_RUN:-0}"
SYNC_TIMEOUT="${GC_BACKUP_REBUILD_SYNC_TIMEOUT_SECS:-1800}"
case "$SYNC_TIMEOUT" in ''|*[!0-9]*|0) SYNC_TIMEOUT=1800 ;; esac
LOCK_WAIT="${GC_BACKUP_REBUILD_LOCK_WAIT_SECS:-900}"
case "$LOCK_WAIT" in ''|*[!0-9]*) LOCK_WAIT=900 ;; esac
LOCK_FILE="${GC_DOLT_BACKUP_LOCK_FILE:-$CITY_ABS/.gc/runtime/packs/dolt/backup-sync.lock}"

# The full sync runs through the dolt client, not gc bd: bd's connection gives
# up on a query after about half a minute, and a full sync of a large
# database takes longer (the cilador-city city store: 41s). Connection
# settings follow the dolt pack's own scripts.
DOLT_HOST="${GC_DOLT_HOST:-127.0.0.1}"
DOLT_USER="${GC_DOLT_USER:-root}"
DOLT_PORT="${GC_DOLT_PORT:-}"
if [ -z "$DOLT_PORT" ]; then
    DOLT_PORT="$(jq -r '.port // empty' "$CITY_ABS/.gc/runtime/packs/dolt/dolt-state.json" 2>/dev/null)"
fi
case "$DOLT_PORT" in
    ''|*[!0-9]*)
        echo "$NAME: cannot find the Dolt server port (set GC_DOLT_PORT)" >&2
        exit 1
        ;;
esac
# The dolt client reads config from its working directory, so run it from an
# empty one.
DOLT_CWD="$(mktemp -d)"
trap 'rm -rf "$DOLT_CWD"' EXIT

dolt_server_sql() {
    # dolt_server_sql <db> <seconds> <query>
    (cd "$DOLT_CWD" && DOLT_CLI_PASSWORD="${GC_DOLT_PASSWORD:-}" timeout "$2" \
        dolt --host "$DOLT_HOST" --port "$DOLT_PORT" --user "$DOLT_USER" --no-tls \
        --use-db "$1" sql -r csv -q "$3")
}

# ── recipient for failure notices ───────────────────────────────────────
TO="${GC_BACKUP_REBUILD_NOTIFY_TO:-}"
if [ -z "$TO" ]; then
    TO="$(gc session list --json 2>/dev/null \
        | jq -r '(if type == "array" then . else (.sessions // .items // []) end)[]
                 | select(((.template // "") | test("(^|\\.)mayor$")))
                 | (.alias // .name // .template)' 2>/dev/null | head -1)"
    [ -n "$TO" ] || TO="mayor"
fi

# ── scopes: the city store, then every rig ──────────────────────────────
# Each line: <rig name, empty for the city store>
SCOPES="$(printf '\n'; gc rig list --json 2>/dev/null \
    | jq -r '(.rigs // [])[] | select((.hq // false) == false) | .name // empty' 2>/dev/null)"

bd_in() {
    # bd_in <rig> <args...>: gc bd scoped to a rig, or the city store.
    local rig="$1"; shift
    if [ -n "$rig" ]; then
        timeout "${BD_TIMEOUT:-120}" gc bd --rig "$rig" "$@"
    else
        timeout "${BD_TIMEOUT:-120}" gc bd "$@"
    fi
}

human_size() {
    du -sh "$1" 2>/dev/null | cut -f1
}

FAILED=0
REBUILT=0
SKIPPED=0
REPORT=""
FAILURES=""

note() {
    echo "$NAME: $*" >&2
    REPORT="$REPORT
  $*"
}

fail_scope() {
    FAILED=$((FAILED + 1))
    note "$1"
    FAILURES="$FAILURES
  $1"
}

# ── lock ────────────────────────────────────────────────────────────────
if [ "$DRY_RUN" != "1" ]; then
    mkdir -p "$(dirname "$LOCK_FILE")"
    exec 9>"$LOCK_FILE"
    if ! flock -w "$LOCK_WAIT" 9; then
        echo "$NAME: backup lock still held after ${LOCK_WAIT}s; skipped, the next run retries"
        exit 0
    fi
fi

# rebuild_scope <rig>: rebuild one scope's backup. Returns 0 when rebuilt or
# skipped, 1 when it failed (the old backup is left in place).
rebuild_scope() {
    local rig="$1"
    local label="${rig:-city}"
    local status url dir parent base db fresh prev verify old_size new_size
    local head in_live

    if ! status="$(bd_in "$rig" backup status --json 2>/dev/null)"; then
        fail_scope "$label: gc bd backup status failed"
        return 1
    fi
    if [ "$(jq -r '.dolt.configured // false' <<<"$status")" != "true" ]; then
        SKIPPED=$((SKIPPED + 1))
        note "$label: no backup destination yet; skipped"
        return 0
    fi
    url="$(jq -r '.dolt.backup_url // empty' <<<"$status")"
    case "$url" in
        file://*) dir="${url#file://}" ;;
        *)
            SKIPPED=$((SKIPPED + 1))
            note "$label: backup is not file:// ($url); skipped"
            return 0
            ;;
    esac
    dir="${dir%/}"
    parent="$(dirname "$dir")"
    base="$(basename "$dir")"
    fresh="$parent/.rebuild-$base"
    prev="$parent/.prev-$base"

    # Recover from an interrupted run before anything else.
    if [ -d "$prev" ]; then
        if [ ! -d "$dir" ]; then
            [ "$DRY_RUN" = "1" ] || mv -f "$prev" "$dir"
            note "$label: restored the backup an interrupted run had moved aside"
        else
            # The swap only happens after verification, so $dir is good.
            [ "$DRY_RUN" = "1" ] || rm -rf "$prev"
        fi
    fi
    [ -e "$fresh" ] && { [ "$DRY_RUN" = "1" ] || rm -rf "$fresh"; }
    if [ "$DRY_RUN" != "1" ]; then
        rm -rf "$parent"/.verify-"$base"-* 2>/dev/null
    fi

    if [ ! -d "$dir" ]; then
        SKIPPED=$((SKIPPED + 1))
        note "$label: backup directory $dir does not exist yet; skipped"
        return 0
    fi
    old_size="$(human_size "$dir")"

    if ! db="$(bd_in "$rig" sql --csv "SELECT DATABASE()" 2>/dev/null | tail -n 1 | tr -d '\r')" \
        || [ -z "$db" ] || [[ "$db" == *[!A-Za-z0-9_-]* ]]; then
        fail_scope "$label: could not read the database name"
        return 1
    fi

    if [ "$DRY_RUN" = "1" ]; then
        note "$label ($db): would rebuild $dir (now $old_size)"
        return 0
    fi

    # 1. fresh copy
    if ! dolt_server_sql "$db" "$SYNC_TIMEOUT" \
        "CALL dolt_backup('sync-url', 'file://$fresh')" >/dev/null 2>"$fresh.err"; then
        fail_scope "$label ($db): sync to a fresh directory failed: $(tr '\n' ' ' <"$fresh.err" | cut -c1-400)"
        rm -rf "$fresh" "$fresh.err"
        return 1
    fi
    rm -f "$fresh.err"

    # 2. verify it restores, is intact, and matches the live history
    verify="$(mktemp -d "$parent/.verify-$base-XXXXXX")" || {
        fail_scope "$label ($db): cannot create a verification directory"
        rm -rf "$fresh"
        return 1
    }
    if ! (cd "$verify" && dolt backup restore "file://$fresh" "$db" >/dev/null 2>&1); then
        fail_scope "$label ($db): the fresh copy did not restore; old backup kept"
        rm -rf "$fresh" "$verify"
        return 1
    fi
    if ! (cd "$verify/$db" && dolt fsck --quiet >/dev/null 2>&1); then
        fail_scope "$label ($db): dolt fsck found problems in the fresh copy; old backup kept"
        rm -rf "$fresh" "$verify"
        return 1
    fi
    head="$(cd "$verify/$db" && dolt sql -r csv -q \
        "SELECT commit_hash FROM dolt_log LIMIT 1" 2>/dev/null | tail -n 1 | tr -d '\r')"
    if ! (cd "$verify/$db" && dolt sql -r csv -q "SELECT COUNT(*) FROM issues" >/dev/null 2>&1) \
        || [[ ! "$head" =~ ^[0-9a-v]{32}$ ]]; then
        fail_scope "$label ($db): the restored copy cannot be read; old backup kept"
        rm -rf "$fresh" "$verify"
        return 1
    fi
    in_live="$(bd_in "$rig" sql --csv \
        "SELECT COUNT(*) FROM dolt_log WHERE commit_hash = '$head'" 2>/dev/null | tail -n 1 | tr -d '\r')"
    if [ "$in_live" != "1" ]; then
        fail_scope "$label ($db): the restored head $head is not in the live history; old backup kept"
        rm -rf "$fresh" "$verify"
        return 1
    fi
    rm -rf "$verify"

    # 3. swap, then delete the old backup
    if ! mv -f "$dir" "$prev"; then
        fail_scope "$label ($db): could not move the old backup aside; old backup kept"
        rm -rf "$fresh"
        return 1
    fi
    if ! mv -f "$fresh" "$dir"; then
        mv -f "$prev" "$dir"
        fail_scope "$label ($db): could not move the fresh copy into place; old backup kept"
        rm -rf "$fresh"
        return 1
    fi
    rm -rf "$prev"
    new_size="$(human_size "$dir")"
    REBUILT=$((REBUILT + 1))
    note "$label ($db): rebuilt, $old_size -> $new_size"
    return 0
}

while IFS= read -r rig; do
    rebuild_scope "$rig"
done <<<"$SCOPES"

SUMMARY="rebuilt: $REBUILT, skipped: $SKIPPED, failed: $FAILED"

if [ "$FAILED" -gt 0 ] && [ "$DRY_RUN" != "1" ]; then
    BODY="The weekly Dolt backup rebuild failed for $FAILED scope(s). Each failed scope kept its old backup, which mol-dog-backup goes on updating, so nothing is unprotected; that backup just keeps growing until a rebuild succeeds.
$FAILURES

Full run:$REPORT

Re-run by hand with: gc order run $NAME"
    gc mail send "$TO" --notify -s "Dolt backup rebuild failed ($SUMMARY)" -m "$BODY" >/dev/null \
        || echo "$NAME: could not mail $TO" >&2
fi

echo "$NAME: $SUMMARY"
[ "$FAILED" -eq 0 ]
