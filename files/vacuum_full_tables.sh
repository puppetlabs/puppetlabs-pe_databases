#!/bin/bash

if [ "$1" = "" ]; then
  echo "Usage: $0 <(facts, catalogs, or other) tables to VACUUM FULL> "
  exit
fi

if [ "$2" = "" ]; then
  SLEEP=300
else
  SLEEP=$2
fi

# TODO: Is this used in PE 2018 and newer? RE: fact_values

if [ "$1" = 'facts' ]; then
  WHERE="'facts', 'factsets', 'fact_paths', 'fact_values'"
elif [ "$1" = 'catalogs' ]; then
  WHERE="'catalogs', 'catalog_resources', 'edges', 'certnames'"
elif [ "$1" = 'other' ]; then
  WHERE="'producers', 'resource_params', 'resource_params_cache'"
else
  echo "Must pass facts, catalogs, or other as first argument"
  exit 1
fi

SQL="SELECT t.relname::varchar AS table_name
  FROM pg_class t
  JOIN pg_namespace n
    ON n.oid = t.relnamespace
  WHERE t.relkind = 'r'
    AND t.relname IN ( $WHERE )"

for TABLE in $(su - pe-postgres -s /bin/bash -c "/opt/puppetlabs/server/bin/psql -d pe-puppetdb -c \"$SQL\" --tuples-only")
do
  # echo "$TABLE"
  su - pe-postgres -s /bin/bash -c "/opt/puppetlabs/server/bin/vacuumdb -d pe-puppetdb -t $TABLE --full --analyze"
  sleep "$SLEEP"
done
