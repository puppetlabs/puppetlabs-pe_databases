# Maintenance pg_repack
#
# @summary Maintenance pg_repack

class pe_databases::maintenance::pg_repack (
  Boolean $disable_maintenance = $pe_databases::maintenance::disable_maintenance,
  String  $logging_directory   = $pe_databases::maintenance::logging_directory,
  Integer $jobs                = $facts['processors']['count'] / 4
) {

  $ensure_cron = $disable_maintenance ? {
    true    => absent,
    default => present
  }

  # PE 2019.1 starting shipping versioned pe-postgres packages where all paths are versioned.
  # So, prior to 2019.1 use a non-versioned path, and after use a versioned path.
  # TODO: Use $pe_databases::psql_version after identifying why it is cast to ${psql_version}00000 in spec tests.
  $postgresql_version = $facts['pe_postgresql_info']['installed_server_version']
  $repack_executable = versioncmp('2019.1.0', $facts['pe_server_version']) ? {
                          1       => '/opt/puppetlabs/server/apps/postgresql/bin/pg_repack',
                          default => "/opt/puppetlabs/server/apps/postgresql/${postgresql_version}/bin/pg_repack"
                          }

  $repack          = "su - pe-postgres -s /bin/bash -c \"${repack_executable} -d pe-puppetdb"
  $repack_jobs     = "--jobs ${jobs}"

  $facts_tables    = '-t factsets -t fact_paths"'
  $catalogs_tables = '-t catalogs -t catalog_resources -t edges -t certnames"'
  $other_tables    = '-t producers -t resource_params -t resource_params_cache"'
  $reports_table   = '-t reports"'
  $resource_events_table = '-t resource_events"'
  $catalog_inputs_table = '-t catalog_inputs"'

  Cron {
    ensure   => $ensure_cron,
    user     => 'root',
    require  => File[$logging_directory],
  }

  cron { 'pg_repack facts tables' :
    weekday => [2,6],
    hour    => 4,
    minute  => 30,
    command => "${repack} ${repack_jobs} ${facts_tables} > ${logging_directory}/facts_repack.log 2>&1",
  }

  cron { 'pg_repack catalogs tables' :
    weekday => [0,4],
    hour    => 4,
    minute  => 30,
    command => "${repack} ${repack_jobs} ${catalogs_tables} > ${logging_directory}/catalogs_repack.log 2>&1",
  }

  cron { 'pg_repack other tables' :
    monthday => 20,
    hour     => 5,
    minute   => 30,
    command  => "${repack} ${repack_jobs} ${other_tables} > ${logging_directory}/other_repack.log 2>&1",
  }

  if versioncmp($facts['pe_server_version'], '2019.7.0') < 0 {
    cron { 'pg_repack reports tables' :
      monthday => 10,
      hour     => 5,
      minute   => 30,
      command  => "${repack} ${repack_jobs} ${reports_table} > ${logging_directory}/reports_repack.log 2>&1",
    }
  }
  else {
    cron { 'pg_repack reports tables' :
      ensure   => 'absent',
    }
  }

  if versioncmp($facts['pe_server_version'], '2019.3.0') < 0 {
    cron { 'pg_repack resource_events tables' :
      monthday => 15,
      hour     => 5,
      minute   => 30,
      command  => "${repack} ${repack_jobs} ${resource_events_table} > ${logging_directory}/resource_events_repack.log 2>&1",
    }
  }
  else {
    cron { 'pg_repack resource_events tables' :
      ensure   => 'absent',
    }
  }

  if versioncmp($facts['pe_server_version'], '2019.8.2') >= 0 {
    cron { 'pg_repack catalog_inputs tables' :
      weekday => [1,5],
      hour    => 4,
      minute  => 30,
      command => "${repack} ${repack_jobs} ${catalog_inputs_table} > ${logging_directory}/catalog_inputs_repack.log 2>&1",
    }
  }
  else {
    cron { 'pg_repack catalog_inputs tables' :
      ensure   => 'absent',
    }
  }

  file { "${logging_directory}/output.log" :
    ensure => absent,
  }
}
