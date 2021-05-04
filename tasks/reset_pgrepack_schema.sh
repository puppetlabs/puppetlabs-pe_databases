#!/bin/sh

# Puppet Task Name: reset_pgrepack_schema

#Remove the pg_repack extension
su - pe-postgres -s '/bin/bash' -c '/opt/puppetlabs/server/bin/psql -d pe-puppetdb -c "DROP EXTENSION pg_repack CASCADE"'

#Then, recreate the pg_repack extension
su - pe-postgres -s '/bin/bash' -c '/opt/puppetlabs/server/bin/psql -d pe-puppetdb -c "CREATE EXTENSION pg_repack"'

echo " -- reset_pgrepack_scheme Task ended: $(date +%s) --"