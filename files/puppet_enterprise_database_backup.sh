#!/bin/bash

BACKUPDIR=/opt/puppetlabs/server/data/postgresql/9.4/backups
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

let RETENTION_ENFORCE=$RETENTION-1

if [[ -z "${DATABASES}" ]]; then
  echo "Usage: $0 [-l LOG_DIRECTORY] [-t BACKUP_TARGET] [-r RETENTION] <DATABASE1> [DATABASE...]"
  exit 1
fi

for db in $DATABASES; do
  echo "Enforcing retention policy of storing only ${RETENTION_ENFORCE} backups for ${db}" >> ${LOGDIR}/${db}.log 2>&1

  ls -1tr ${BACKUPDIR}/${db}_* | head -n -${RETENTION_ENFORCE} | xargs -d '\n' rm -f --

  echo "Starting dump of database: ${db}" >> ${LOGDIR}/${db}.log 2>&1

  if [ ${db} == "pe-classifier" ]; then
    #Save space before backing up by clearing unused node_check_ins table
    /opt/puppetlabs/server/bin/psql -d pe-classifier -c 'TRUNCATE TABLE node_check_ins' >> ${LOGDIR}/${db}.log 2>&1
    if [ $? != 0 ]; then
      echo "Failed to truncate node_check_ins table." >> ${LOGDIR}/${db}.log 2>&1
    fi
  fi

  /opt/puppetlabs/server/bin/pg_dump -Fc ${db} -f ${BACKUPDIR}/${db}_`date +%m_%d_%y_%H_%M`.bin >> ${LOGDIR}/${db}.log 2>&1

  result=$?
  if [[ $result -eq 0 ]]; then
    echo "Completed dump of database: ${db}" >> ${LOGDIR}/${db}.log 2>&1
  else
    echo "Failed to dump database ${db}. Exit code is: ${result}" >> ${LOGDIR}/${db}.log 2>&1
    exit 1
  fi
done
