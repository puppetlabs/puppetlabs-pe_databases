#!/bin/bash

# Puppet Task Name: reset_pgrepack_schema
declare PT__installdir
# shellcheck disable=SC1090
source "$PT__installdir/pe_databases/files/common.sh"

#Determine if PE Postgres is available
if puppet resource service pe-postgresql | grep -q running; then
    #Remove the pg_repack extension
    su - pe-postgres -s '/bin/bash' -c '/opt/puppetlabs/server/bin/psql -d pe-puppetdb -c "DROP EXTENSION pg_repack CASCADE"' || fail "unable to drop pg_repack extension"

    #Then, recreate the pg_repack extension
    su - pe-postgres -s '/bin/bash' -c '/opt/puppetlabs/server/bin/psql -d pe-puppetdb -c "CREATE EXTENSION pg_repack"' || fail "unable to create pg_repack estenstion"
else
  fail "No running PE-PostgreSQL instance found, please run this task against your Primary or PE-PostgreSQL server"
fi


success '{ "status": "success" }'
