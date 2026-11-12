#!/bin/bash
# Removes what an interrupted pg_repack run leaves behind in a database (the
# repack_trigger on a table and the repack.* log and table objects) by dropping
# and recreating the pg_repack extension.

usage() {
  cat <<'EOF'
Usage: repack_cleanup.sh [--manual] [--siblings <unit>[,<unit>...]] <database> [table ...]

Removes leftovers of an interrupted pg_repack run (repack_trigger and repack.*
objects) from <database> by dropping and recreating the pg_repack extension.
Every table in the database that carries repack_trigger is cleaned up. The
tables given are this job's tables, names in schema public; with no tables,
every table in the database is this job's. A pg_repack session that holds
locks on a table that is not this job's makes the script skip; pg_repack
sessions on this job's tables are terminated.

Options:
  --siblings <units>  Comma-separated systemd units of the other repack jobs that
                      use the same database. If any of them is running, nothing
                      is changed.
  --manual            Do not check for other running repack jobs, terminate
                      every pg_repack session in the database, and always drop
                      and recreate the extension, even with no leftovers.
                      Without --manual, the extension is left alone when no
                      table carries repack_trigger.

Environment:
  PSQL  path to psql (default /opt/puppetlabs/server/bin/psql)

Exit codes:
  0  nothing to clean up, or cleaned up
  1  error
  2  skipped, another repack job is running in the database
  3  could not get the locks within the lock timeout, the pg_repack extension
     was not changed
EOF
}

die() {
  echo "repack_cleanup: $1" >&2
  exit "${2:-1}"
}

if [ "$EUID" -eq 0 ]; then
  case $0 in
    /*) self=$0 ;;
    *) self=$PWD/$0 ;;
  esac
  cd / || die "could not change to /"
  command -v runuser >/dev/null 2>&1 || die "runuser not found, cannot switch to pe-postgres"
  runuser -u pe-postgres -- /bin/bash "$self" "$@"
  rc=$?
  case $rc in
    0 | 1 | 2 | 3) exit $rc ;;
    *) die "could not run $self as pe-postgres (exit $rc)" ;;
  esac
fi

cd / || die "could not change to /"

PSQL=${PSQL:-/opt/puppetlabs/server/bin/psql}
export PGAPPNAME=repack_cleanup
# Bound connecting and every statement so a wedged server cannot hang the script,
# and resolve every name in pg_catalog so that objects in other schemas cannot
# shadow the functions the script calls.
export PGCONNECT_TIMEOUT=10
export PGOPTIONS="${PGOPTIONS:+$PGOPTIONS }-c statement_timeout=60s -c search_path=pg_catalog,pg_temp"

manual=false
siblings=()
while [ $# -gt 0 ]; do
  case $1 in
    --manual)
      manual=true
      shift
      ;;
    --siblings)
      [ $# -ge 2 ] || die "--siblings needs a comma-separated list of units"
      IFS=, read -r -a units <<<"$2"
      for unit in "${units[@]}"; do
        [ -n "$unit" ] && siblings+=("$unit")
      done
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      usage >&2
      die "unknown option: $1"
      ;;
    *)
      break
      ;;
  esac
done

if [ $# -lt 1 ] || [ -z "$1" ]; then
  usage >&2
  die "no database given"
fi
database=$1
shift
tables=("$@")

for unit in "${siblings[@]}"; do
  case $unit in
    -*) die "invalid unit name: $unit" ;;
  esac
done

if [ ${#tables[@]} -eq 0 ]; then
  all_tables=true
else
  all_tables=false
fi
table_list=$(printf '%s\n' "${tables[@]}")

run_sql() {
  "$PSQL" -X -q -A -t -v ON_ERROR_STOP=1 \
    -v all_tables="$all_tables" -v tables="$table_list" -v manual="$manual" "$@" \
    -d "$database" 2>&1
}

# Relations that belong to this job.
job_cte() {
  cat <<'SQL'
SET client_min_messages = warning;
WITH job AS (
  SELECT c.oid
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE (:all_tables AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'repack'))
     OR (n.nspname = 'public' AND c.relname = ANY (string_to_array(:'tables', E'\n')))
)
SQL
}

# Tables in the database that carry repack_trigger, as the FROM and WHERE clauses of a query.
trigger_tables_from() {
  cat <<'SQL'
FROM pg_trigger t
JOIN pg_class c ON c.oid = t.tgrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE t.tgname = 'repack_trigger'
  AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'repack')
SQL
}

# 1. Tables that carry repack_trigger.
out=$(
  {
    echo 'SET client_min_messages = warning;'
    echo "SELECT 'table|' || format('%I.%I', n.nspname, c.relname)"
    trigger_tables_from
    echo 'ORDER BY 1;'
    echo "SELECT 'done';"
  } | run_sql
)
rc=$?
if [ $rc -ne 0 ] || ! grep -qx 'done' <<<"$out"; then
  die "could not read repack_trigger tables in database $database (psql exit $rc): $out"
fi
trigger_tables=$(sed -n 's/^table|//p' <<<"$out")
if [ -z "$trigger_tables" ]; then
  if [ "$manual" = false ]; then
    echo "repack_cleanup: no repack_trigger in database $database, nothing to do"
    exit 0
  fi
  echo "repack_cleanup: no repack_trigger in database $database"
else
  trigger_desc=$(tr '\n' ' ' <<<"$trigger_tables")
  trigger_desc=${trigger_desc% }
  echo "repack_cleanup: repack_trigger found on $trigger_desc in database $database"
fi

# 1b. Other repack jobs that use this database.
if [ "$manual" = false ]; then
  for unit in "${siblings[@]}"; do
    state=$(systemctl show -p ActiveState "$unit" 2>/dev/null) ||
      die "could not read the state of $unit (systemctl exit $?)"
    state=${state#ActiveState=}
    case $state in
      activating | active | reloading | deactivating)
        die "skipped: $unit is $state and uses database $database, so its pg_repack run may own this residue; nothing was changed" 2
        ;;
    esac
  done
fi

# 2. Classify pg_repack sessions by the tables their relation locks belong to.
# Indexes count as their table, TOAST tables as their owning table.
out=$(
  {
    job_cte
    cat <<'SQL'
, sessions AS (
  SELECT pid
  FROM pg_stat_activity
  WHERE datname = current_database()
    AND application_name = 'pg_repack'
    AND pid <> pg_backend_pid()
), locked AS (
  SELECT l.pid, COALESCE(i.indrelid, l.relation) AS rel
  FROM pg_locks l
  JOIN sessions s ON s.pid = l.pid
  LEFT JOIN pg_index i ON i.indexrelid = l.relation
  WHERE l.locktype = 'relation'
    AND l.database = (SELECT oid FROM pg_database WHERE datname = current_database())
), owned AS (
  SELECT lk.pid, COALESCE(o.oid, c.oid) AS tbl
  FROM locked lk
  JOIN pg_class c ON c.oid = lk.rel
  LEFT JOIN pg_class o ON c.relkind = 't' AND o.reltoastrelid = c.oid
), classified AS (
  SELECT ow.pid,
         format('%I.%I', n.nspname, c.relname) AS name,
         CASE
           WHEN n.nspname IN ('pg_catalog', 'information_schema') THEN 'ignore'
           WHEN n.nspname = 'repack' THEN 'job'
           WHEN ow.tbl IN (SELECT oid FROM job) THEN 'job'
           ELSE 'other'
         END AS kind
  FROM owned ow
  JOIN pg_class c ON c.oid = ow.tbl
  JOIN pg_namespace n ON n.oid = c.relnamespace
)
SELECT 'session|' || s.pid || '|'
       || CASE
            WHEN bool_or(cl.kind = 'other') THEN 'other'
            WHEN bool_or(cl.kind = 'job') THEN 'job'
            ELSE 'idle'
          END
       || '|' || COALESCE(string_agg(DISTINCT cl.name, ',') FILTER (WHERE cl.kind = 'other'), '')
FROM sessions s
LEFT JOIN classified cl ON cl.pid = s.pid
GROUP BY s.pid
ORDER BY s.pid;
SELECT 'done';
SQL
  } | run_sql
)
rc=$?
if [ $rc -ne 0 ] || ! grep -qx 'done' <<<"$out"; then
  die "could not list pg_repack sessions in database $database (psql exit $rc): $out"
fi

pid_query() {
  printf "SELECT %s FROM pg_stat_activity WHERE datname = current_database() AND application_name = 'pg_repack' AND pid = ANY (string_to_array(:'pids', ',')::int[]);\n" "$1"
}

terminate=()
while IFS='|' read -r tag pid kind others; do
  [ "$tag" = session ] || continue
  if [ "$manual" = true ]; then
    terminate+=("$pid")
  elif [ "$kind" = other ]; then
    die "skipped: pg_repack session $pid holds locks on $others, which are not in this job's tables, so another repack job may be running in database $database; nothing was changed" 2
  elif [ "$kind" = job ]; then
    terminate+=("$pid")
  fi
done <<<"$out"

if [ ${#terminate[@]} -gt 0 ]; then
  pids=$(IFS=,; echo "${terminate[*]}")
  echo "repack_cleanup: terminating pg_repack session(s) $pids"
  out=$(pid_query 'pg_terminate_backend(pid)' | run_sql -v pids="$pids") ||
    die "could not terminate pg_repack sessions $pids in database $database: $out"
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    left=$(pid_query 'count(*)' | run_sql -v pids="$pids") ||
      die "could not check pg_repack sessions in database $database: $left"
    [ "$left" = 0 ] && break
    sleep 1
  done
  if [ "$left" != 0 ]; then
    echo "repack_cleanup: $left pg_repack session(s) still present after 10 s" >&2
  fi
fi

# 3. Lock the tables carrying repack_trigger, then drop and recreate the extension.
# Without --manual, nothing is dropped when no table carries repack_trigger any more.
out=$(
  {
    echo '\set VERBOSITY verbose'
    echo 'SET client_min_messages = warning;'
    echo 'BEGIN;'
    echo "SET LOCAL lock_timeout = '5s';"
    echo "SELECT format('LOCK TABLE %s IN ACCESS EXCLUSIVE MODE',"
    echo "              string_agg(format('%I.%I', n.nspname, c.relname), ', ' ORDER BY n.nspname, c.relname))"
    trigger_tables_from
    echo 'HAVING count(*) > 0'
    echo '\gexec'
    echo "SELECT 'table|' || format('%I.%I', n.nspname, c.relname)"
    trigger_tables_from
    echo 'ORDER BY 1;'
    echo "SELECT :manual OR count(*) > 0 AS recreate"
    trigger_tables_from
    echo '\gset'
    cat <<'SQL'
\if :recreate
-- CREATE EXTENSION puts the extension in the first schema of the search path
SET LOCAL search_path = public, pg_catalog;
DROP EXTENSION IF EXISTS pg_repack CASCADE;
CREATE EXTENSION pg_repack;
SELECT 'recreated';
\endif
COMMIT;
SELECT 'done';
SQL
  } | run_sql
)
rc=$?
if [ $rc -ne 0 ] || ! grep -qx 'done' <<<"$out"; then
  if grep -qx 'recreated' <<<"$out"; then
    die "could not confirm the outcome in database $database (psql exit $rc): the pg_repack extension was dropped and recreated but the transaction may not have been committed, check the state of the pg_repack extension: $out"
  fi
  if grep -q '55P03' <<<"$out"; then
    die "could not get the locks needed in database $database within 5 s because another session holds a conflicting lock; the pg_repack extension was not changed" 3
  fi
  die "could not complete the cleanup in database $database (psql exit $rc); the pg_repack extension was not changed: $out"
fi
removed_tables=$(sed -n 's/^table|//p' <<<"$out")
if ! grep -qx 'recreated' <<<"$out"; then
  echo "repack_cleanup: no repack_trigger left in database $database, nothing to do"
elif [ -z "$removed_tables" ]; then
  echo "repack_cleanup: recreated the pg_repack extension in database $database, no leftovers were found"
else
  removed_desc=$(tr '\n' ' ' <<<"$removed_tables")
  echo "repack_cleanup: removed pg_repack leftovers from ${removed_desc% } and recreated the pg_repack extension in database $database"
fi
exit 0
