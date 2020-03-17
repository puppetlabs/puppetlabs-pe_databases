#!/bin/bash

usage() {
  cat <<EOF
echo "usage: $0 <table>"
where <table> is one of: facts catalogs other
EOF
  exit 1
}
# Print usage if given 0 arguments
(( $# == 0 )) && usage

sleep_duration="${2:-300}"

# TODO: Is this used in PE 2018 and newer? RE: fact_values
case "$1" in
  'facts')
    vacuum_tables=("'facts'" "'factsets'" "'fact_paths'" "'fact_values'")
    ;;
  'catalogs')
    vacuum_tables=("'catalogs'" "'catalog_resources'" "'edges'" "'certnames'")
    ;;
  'other')
    vacuum_tables=("'producers'" "'resource_params'" "'resource_params_cache'")
    ;;
  *)
    usage
esac


SQL="SELECT t.relname::varchar AS table_name
  FROM pg_class t
  JOIN pg_namespace n
    ON n.oid = t.relnamespace
  WHERE t.relkind = 'r'
    AND t.relname IN ( $(IFS=,; echo "${vacuum_tables[*]}") )"

tables=($(su - pe-postgres -s /bin/bash -c "/opt/puppetlabs/server/bin/psql -d pe-puppetdb -c \"$SQL\" --tuples-only"))

for table in "${tables[@]}"; do
  su - pe-postgres -s /bin/bash -c "/opt/puppetlabs/server/bin/vacuumdb -d pe-puppetdb -t $table --full --analyze"
  sleep "$sleep_duration"
done
