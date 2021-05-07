#!/bin/sh

# Puppet Task Name: reset_pgrepack_schema

#Determine if PE Postgres is available
if puppet resource service pe-postgresql | grep -q running; then
    #Remove the pg_repack extension
    su - pe-postgres -s '/bin/bash' -c '/opt/puppetlabs/server/bin/psql -d pe-puppetdb -c "DROP EXTENSION pg_repack CASCADE"'

    #Then, recreate the pg_repack extension
    su - pe-postgres -s '/bin/bash' -c '/opt/puppetlabs/server/bin/psql -d pe-puppetdb -c "CREATE EXTENSION pg_repack"'
else
  echo " -- No running PE-PostgreSQL instance found, please run this task against your Primary or PE-PostgreSQL server --"
fi

echo " -- reset_pgrepack_scheme Task ended: $(date +%s) --"
