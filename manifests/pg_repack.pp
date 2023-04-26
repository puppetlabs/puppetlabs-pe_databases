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
# @param reports_tables_repack_timer [String] Deprecated Parameter will be removed in future releases
# @param resource_events_tables_repack_timer [String] Deprecated Parameter will be removed in future releases
class pe_databases::pg_repack (
  Boolean $disable_maintenance                          = false,
  Integer $jobs                                         = $facts['processors']['count'] / 4,
  String[1] $facts_tables_repack_timer                  = $pe_databases::facts_tables_repack_timer,
  String[1] $catalogs_tables_repack_timer               = $pe_databases::catalogs_tables_repack_timer,
  String[1] $other_tables_repack_timer                  = $pe_databases::other_tables_repack_timer,
  Optional[String] $reports_tables_repack_timer         = undef,
  Optional[String] $resource_events_tables_repack_timer = undef,
) {
  puppet_enterprise::deprecated_parameter { 'pe_databases::pg_repack::reports_tables_repack_timer': }
  puppet_enterprise::deprecated_parameter { 'pe_databases::pg_repack::resource_events_tables_repack_timer': }

  $postgresql_version = $facts['pe_postgresql_info']['installed_server_version']
  $repack_executable = "/opt/puppetlabs/server/apps/postgresql/${postgresql_version}/bin/pg_repack"

  $repack_cmd = "${repack_executable} -d pe-puppetdb --jobs ${jobs}"

  $fact_tables = '-t factsets -t fact_paths'
  $catalog_tables = '-t catalogs -t catalog_resources -t catalog_inputs -t edges -t certnames'
  $other_tables = '-t producers -t resource_params -t resource_params_cache'

  pe_databases::collect { 'facts':
    disable_maintenance => $disable_maintenance,
    command             => "${repack_cmd} ${fact_tables}",
    on_cal              => $facts_tables_repack_timer,
  }

  pe_databases::collect { 'catalogs':
    disable_maintenance => $disable_maintenance,
    command             => "${repack_cmd} ${catalog_tables}",
    on_cal              => $catalogs_tables_repack_timer,
  }

  pe_databases::collect { 'other':
    disable_maintenance => $disable_maintenance,
    command             => "${repack_cmd} ${other_tables}",
    on_cal              => $other_tables_repack_timer,
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
