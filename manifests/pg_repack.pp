# Maintenance pg_repack
#
# @summary 
#   Provides systemd timers to pg_repack tables in the pe-puppetdb database

class pe_databases::pg_repack (
  Boolean $disable_maintenance = false,
  Integer $jobs                = $facts['processors']['count'] / 4
) {

  # PE 2019.1 starting shipping versioned pe-postgres packages where all paths are versioned.
  # So, prior to 2019.1 use a non-versioned path, and after use a versioned path.
  # TODO: Use $pe_databases::psql_version after identifying why it is cast to ${psql_version}00000 in spec tests.
  $postgresql_version = $facts['pe_postgresql_info']['installed_server_version']
  $repack_executable = versioncmp('2019.1.0', $facts['pe_server_version']) ? {
                          1       => '/opt/puppetlabs/server/apps/postgresql/bin/pg_repack',
                          default => "/opt/puppetlabs/server/apps/postgresql/${postgresql_version}/bin/pg_repack"
                          }

  $repack          = "${repack_executable} -d pe-puppetdb"
  $repack_jobs     = "--jobs ${jobs}"

  $facts_tables    = '-t factsets -t fact_paths'
  $catalogs_tables = versioncmp($facts['pe_server_version'], '2019.8.1') ? {
                      1       => '-t catalogs -t catalog_resources -t catalog_inputs -t edges -t certnames',
                      default => '-t catalogs -t catalog_resources -t edges -t certnames' }
  $other_tables    = '-t producers -t resource_params -t resource_params_cache'
  $reports_table   = '-t reports'
  $resource_events_table = '-t resource_events'

  pe_databases::collect {'facts':
    disable_maintenance => $disable_maintenance,
    command             => "${repack} ${repack_jobs} ${facts_tables}",
    on_cal              => 'Tue,Sat *-*-* 04:30:00',
  }

  pe_databases::collect {'catalogs':
    disable_maintenance => $disable_maintenance,
    command             => "${repack} ${repack_jobs} ${catalogs_tables}",
    on_cal              => 'Sun,Thu *-*-* 04:30:00',
  }

  pe_databases::collect {'other':
    disable_maintenance => $disable_maintenance,
    command             => "${repack} ${repack_jobs} ${other_tables}",
    on_cal              => '*-*-20 05:30:00',
  }

  if versioncmp($facts['pe_server_version'], '2019.7.0') < 0 {
    pe_databases::collect {'reports':
      disable_maintenance => $disable_maintenance,
      command             => "${repack} ${repack_jobs} ${reports_table}",
      on_cal              => '*-*-10 05:30:00',
    }
  }

  if versioncmp($facts['pe_server_version'], '2019.3.0') < 0 {
    pe_databases::collect {'resource_events':
      disable_maintenance => $disable_maintenance,
      command             => "${repack} ${repack_jobs} ${resource_events_table}",
      on_cal              => '*-*-15 05:30:00',
    }
  }

  # Ensure legacy vaccum and pg_repack crons are purged.
  # If someone upgrades from an ancient v0.x version of the pe_databases module to 2.0 or newer, 
  # the old cron jobs running vaccuum full will not be cleaned up. This can result in a deadlock 
  # when both pg_repack and vacuum full attempt to update a table
  $legacy_crons = [
    'pg_repack facts tables', 'pg_repack catalogs tables', 'pg_repack other tables',
    'pg_repack reports tables', 'pg_repack resource_events tables',
    'VACUUM FULL facts tables',
    'VACUUM FULL catalogs tables',
    'VACUUM FULL other tables',
    'Maintain PE databases',
  ]
  cron { $legacy_crons:
      ensure => absent,
  }
}
