# Maintenance pg_repack
#
# @summary 
#   Provides systemd timers to pg_repack tables in the pe-puppetdb database
# 
# @param disable_maintenance [Boolean] true or false (Default: false)
#   Disable or enable maintenance mode
# @param jobs [Integer] How many jobs to run in parallel
# @param facts_tables_repack_timer [String] The Systemd timer for the pg_repack job affecting the 'facts' tables
# @param catalogs_tables_repack_timer [String]The Systemd timer for the pg_repack job affecting the 'catalog' tables
# @param other_tables_repack_timer [String] The Systemd timer for the pg_repack job affecting the 'other' tables
# @param reports_tables_repack_timer [String] The Systemd timer for the pg_repack job affecting the 'reports' tables
# @param resource_events_tables_repack_timer [String] The Systemd timer for the pg_repack job affecting the 'resource_events' tables
class pe_databases::pg_repack (
  Boolean $disable_maintenance                   = false,
  Integer $jobs                                  = $facts['processors']['count'] / 4,
  String[1] $facts_tables_repack_timer           = $pe_databases::facts_tables_repack_timer,
  String[1] $catalogs_tables_repack_timer        = $pe_databases::catalogs_tables_repack_timer,
  String[1] $other_tables_repack_timer           = $pe_databases::other_tables_repack_timer,
  String[1] $reports_tables_repack_timer         = $pe_databases::reports_tables_repack_timer,
  String[1] $resource_events_tables_repack_timer = $pe_databases::resource_events_tables_repack_timer,
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

  pe_databases::collect { 'facts':
    disable_maintenance => $disable_maintenance,
    command             => "${repack} ${repack_jobs} ${facts_tables}",
    on_cal              => $facts_tables_repack_timer,
  }

  pe_databases::collect { 'catalogs':
    disable_maintenance => $disable_maintenance,
    command             => "${repack} ${repack_jobs} ${catalogs_tables}",
    on_cal              => $catalogs_tables_repack_timer,
  }

  pe_databases::collect { 'other':
    disable_maintenance => $disable_maintenance,
    command             => "${repack} ${repack_jobs} ${other_tables}",
    on_cal              => $other_tables_repack_timer,
  }

  if versioncmp($facts['pe_server_version'], '2019.7.0') < 0 {
    pe_databases::collect { 'reports':
      disable_maintenance => $disable_maintenance,
      command             => "${repack} ${repack_jobs} ${reports_table}",
      on_cal              => $reports_tables_repack_timer,
    }
  }

  if versioncmp($facts['pe_server_version'], '2019.3.0') < 0 {
    pe_databases::collect { 'resource_events':
      disable_maintenance => $disable_maintenance,
      command             => "${repack} ${repack_jobs} ${resource_events_table}",
      on_cal              => $resource_events_tables_repack_timer,
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
