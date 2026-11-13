#!/bin/bash

# Puppet Task Name: reset_pgrepack_schema
declare PT__installdir
# shellcheck disable=SC1090
source "$PT__installdir/pe_databases/files/common.sh"

database=${database:-pe-puppetdb}

if [[ $database != 'pe-puppetdb' && $database != 'pe-activity' ]]; then
  fail "invalid database name, the database must be one of pe-puppetdb or pe-activity"
fi

#Determine if PE Postgres is available
if ! puppet resource service pe-postgresql | grep -q running; then
  fail "No running PE-PostgreSQL instance found, please run this task against your Primary or PE-PostgreSQL server"
fi

if [[ $database == 'pe-activity' ]]; then
  units=(pe_databases-activity.service)
else
  units=(pe_databases-facts.service pe_databases-catalogs.service pe_databases-other.service)
fi

#Refuse while a repack service for this database is running
for unit in "${units[@]}"; do
  state=$(systemctl show -p ActiveState "$unit") || fail "could not read the state of $unit"
  state=${state#ActiveState=}
  case $state in
    activating | active | deactivating | reloading)
      fail "$unit is running (state: $state), stop it and run this task again"
      ;;
  esac
done

#Copy the cleanup script where the pe-postgres user can read it
cleanup_dir=$(mktemp -d) || fail "unable to create a temporary directory"
trap 'rm -rf "$cleanup_dir"' EXIT
chmod 755 "$cleanup_dir"
install -m 0755 "$PT__installdir/pe_databases/files/repack_cleanup.sh" "$cleanup_dir/repack_cleanup.sh" || fail "unable to copy repack_cleanup.sh"

output=$(bash "$cleanup_dir/repack_cleanup.sh" --manual -- "$database" 2>&1)
rc=$?
# Make the text safe to embed in JSON
output=$(tr "\"\\\\\n\t\r" "'/   " <<<"$output" | tr -d '[:cntrl:]')

case $rc in
  0) ;;
  3) fail "could not lock the tables within 5 seconds, look for long-running transactions and run this task again" ;;
  *) fail "repack cleanup failed (exit $rc): $output" ;;
esac

success '{ "status": "success" }'
