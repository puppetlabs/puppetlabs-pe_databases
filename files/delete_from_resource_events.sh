#!/bin/bash

if [ "$1" -ge 0 ] 2>/dev/null; then
  DAYS=$1
else
  DAYS=2
  # echo "Usage: $0 <OLDER THAN DAYS> "
  # exit
fi

SQL="DELETE FROM resource_events WHERE timestamp < NOW() - INTERVAL '$DAYS days'"

su - pe-postgres -s /bin/bash -c "/opt/puppetlabs/server/bin/psql -d pe-puppetdb -c \"$SQL\""
