#!/bin/bash

while [[ $1 ]]; do
  case "$1" in
    -t)
      backup_dir="$2"
      shift 2
      ;;
    -l)
      log_dir="$2"
      shift 2
      ;;
    -r)
      retention="$2"
      shift 2
      ;;
    # If given the end of options string, shift it out and break
    --)
      shift
      break
      ;;
    # No need to shift if we've processed all options
    *)
      break
      ;;
  esac
done

# The remaining parameters will be the databases to backup
databases=("$@")
# shellcheck disable=SC2128
# We only care if the array contains any elements
[[ $databases ]] || {
  echo "Usage: $0  [-t BACKUP_TARGET] [-l LOG_DIRECTORY] [-r retention] <DATABASE> [DATABASE_N ...]"
  exit 1
}

[[ $pg_version ]] || pg_version="$(/usr/local/bin/facter -p pe_postgresql_info.installed_server_version)"
backup_dir="${backup_dir:-/opt/puppetlabs/server/data/postgresql/$pg_version/backups}"
log_dir="${log_dir:-/var/log/puppetlabs/pe_databases_backup}"
retention="${retention:-2}"

for db in "${databases[@]}"; do
  # For each db, redirect all output to the log inside the backup dir
  exec &>"${log_dir}/${db}.log"
  echo "Enforcing retention policy of storing only $retention backups for $db"

  unset backups
  # Starting inside <(), use stat to print mtime and the filename and pipe to sort
  # Add the filename to the backups array, giving us a sorted list of filenames
  while IFS= read -r -d '' line; do
    backups+=("${line#* }")
  done < <(stat --printf '%Y %n\0' "${backup_dir}/${db}_"* 2>/dev/null | sort -nz)

  # Our array offset will be the number of backups - $retention + 1
  # e.g. if we have 2 existing backups and retention=2, offset will be one
  # We'll delete from element 0 to 1 of the array, leaving one backup.
  # The subsequent backup will leave us with 2 again
  offset=$(( ${#backups[@]} - retention + 1 ))

  if (( offset > 0 )); then
  # Continue if we're retaining more copies of the db than currently exist
  # This will also be true if no backups currently exist
    rm -f -- "${backups[@]:0:$offset}"
  fi


  echo "Starting dump of database: $db"

  if [[ $db == 'pe-classifier' ]]; then
    # Save space before backing up by clearing unused node_check_ins table.
    /opt/puppetlabs/server/bin/psql -d pe-classifier -c 'TRUNCATE TABLE node_check_ins' || \
      echo "Failed to truncate node_check_ins table"
  fi

  datetime="$(date +%Y%m%d%S)"

  /opt/puppetlabs/server/bin/pg_dump -Fc "$db" -f "${backup_dir}/${db}_$datetime.bin" || {
    echo "Failed to dump database $db"
    exit 1
  }

  echo "Completed dump of database: ${db}"
done
