# A description of what this class does
#
# @summary A short summary of the purpose of this class
#
# @example
#   include pe_databases::maintenance::pg_repack
class pe_databases::maintenance::pg_repack (
  Boolean $disable_maintenance = $pe_databases::maintenance::disable_maintenance,
  String  $logging_directory   = $pe_databases::maintenance::logging_directory,
) {

  $ensure_cron = $disable_maintenance ? {
    true    => absent,
    default => present
  }

  $repack          = 'su - pe-postgres -s /bin/bash -c "/opt/puppetlabs/server/apps/postgresql/bin/pg_repack -d pe-puppetdb'
  $facts_tables    = '-t factsets -t fact_paths"'
  $catalogs_tables = '-t catalogs -t catalog_resources -t edges -t certnames"'
  $other_tables    = '-t producers -t resource_params -t resource_params_cache"'
  $reports_tables  = '-t reports"'
  $logging         = "> ${logging_directory}/output.log 2>&1"

  Cron {
    ensure   => $ensure_cron,
    user     => 'root',
    require  => File[$logging_directory],
  }

  cron { 'pg_repack facts tables' :
    weekday => [2,6],
    hour     => 4,
    minute   => 30,
    command  => "${repack} ${facts_tables} ${logging}",
  }

  cron { 'pg_repack catalogs tables' :
    weekday  => [0,4],
    hour     => 4,
    minute   => 30,
    command  => "${repack} ${catalogs_tables} ${logging}",
  }

  cron { 'pg_repack other tables' :
    monthday => 20,
    hour     => 5,
    minute   => 30,
    command  => "${repack} ${other_tables} ${logging}",
  }

  cron { 'pg_repack reports tables' :
    ensure   => $ensure_cron,
    user     => 'root',
    monthday => 10,
    hour     => 5,
    minute   => 30,
    command  => "${repack} ${reports_tables} ${logging}",
  }
}
