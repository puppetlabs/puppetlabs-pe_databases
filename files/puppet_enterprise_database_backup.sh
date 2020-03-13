#!/bin/bash

PG_VERSION=$(/usr/local/bin/facter -p pe_postgresql_info.installed_server_version)
BACKUPDIR=/opt/puppetlabs/server/data/postgresql/$PG_VERSION/backups
LOGDIR=/var/log/puppetlabs/pe_databases_backup
RETENTION=2

while [[ $# -gt 0 ]]; do
  arg="$1"
  case $arg in
    -t)
      BACKUPDIR="$2"
      shift; shift
      ;;
    -l)
      LOGDIR="$2"
      shift; shift
      ;;
    -r)
      RETENTION="$2"
      shift; shift
      ;;
    *)
      DATABASES="${DATABASES} $1"
      shift
      ;;
  esac
done

if [[ -z "${DATABASES}" ]]; then
  echo "Usage: $0  [-t BACKUP_TARGET] [-l LOG_DIRECTORY] [-r RETENTION] <DATABASE> [DATABASE_N ...]"
  exit 1
fi

RETENTION_ENFORCE=$((RETENTION-1))

for db in $DATABASES; do
  echo "Enforcing retention policy of storing only ${RETENTION_ENFORCE} backups for ${db}" >> "${LOGDIR}/${db}.log" 2>&1

  ls -1tr ${BACKUPDIR}/${db}_* | head -n -${RETENTION_ENFORCE} | xargs -d '\n' rm -f --

  echo "Starting dump of database: ${db}" >> "${LOGDIR}/${db}.log" 2>&1

  if [ "${db}" == "pe-classifier" ]; then
    # Save space before backing up by clearing unused node_check_ins table.
    /opt/puppetlabs/server/bin/psql -d pe-classifier -c 'TRUNCATE TABLE node_check_ins' >> "${LOGDIR}/${db}.log" 2>&1

    result=$?
    if [ $result != 0 ]; then
      echo "Failed to truncate node_check_ins table" >> "${LOGDIR}/${db}.log" 2>&1
    fi
  fi

  DATETIME=$(date +%m_%d_%y_%H_%M)

  /opt/puppetlabs/server/bin/pg_dump -Fc "${db}" -f "${BACKUPDIR}/${db}_$DATETIME.bin" >> "${LOGDIR}/${db}.log" 2>&1

  result=$?
  if [[ $result -eq 0 ]]; then
    echo "Completed dump of database: ${db}" >> "${LOGDIR}/${db}.log" 2>&1
  else
    echo "Failed to dump database ${db}. Exit code is: ${result}" >> "${LOGDIR}/${db}.log" 2>&1
    exit 1
  fi
done
