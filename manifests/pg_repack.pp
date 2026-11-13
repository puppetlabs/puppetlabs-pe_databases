# Maintenance pg_repack
#
# @summary
#   Provides systemd timers to pg_repack tables in a given database
# @param fact_tables [Array] Array of 'fact' tables to repack
# @param catalog_tables [Array] Array of 'catalog' tables to repack
# @param other_tables [Array] Array of 'other' tables to repack
# @param activity_tables [Array] Array of 'activity' tables to repack
# @param disable_maintenance [Boolean] true or false (Default: false)
#   Disable or enable maintenance mode
# @param repack_log_level [Enum] Desired output level of logs
# @param enable_echo [Boolean] true or false (Default: true)
#   Enabling echo output in logs
# @param kill_backend [Boolean] true or false (Default: true)
#   When true, pg_repack cancels backends that hold conflicting locks. When false, pg_repack
#   is run with --no-kill-backend, so a job skips a table it cannot lock, still exits 0, and the
#   skip is visible only in the job's log.
# @param wait_timeout [Optional[Integer[1]]] Number of seconds pg_repack waits for a lock on a table (the -T option)
#   before it cancels the conflicting backends. After twice that value it terminates them
#   (when kill_backend is true). When unset, the option is not passed and the pg_repack default applies.
# @param max_runtime [Pe_databases::Timespan] Maximum time each repack service may run before systemd stops it, as a systemd
#   time span (for example '12h'). systemd sends SIGTERM to the wrapper script, which stops pg_repack with SIGINT.
# @param stop_timeout [Pe_databases::Timespan] Maximum time systemd waits for a stopping job, including pg_repack's abort and the
#   cleanup, before it kills it, as a systemd time span (for example '10min').
# @param jobs [Integer] How many jobs to run in parallel
# @param facts_tables_repack_timer [String] The Systemd timer for the pg_repack job affecting the 'facts' tables
# @param catalogs_tables_repack_timer [String]The Systemd timer for the pg_repack job affecting the 'catalog' tables
# @param other_tables_repack_timer [String] The Systemd timer for the pg_repack job affecting the 'other' tables
# @param activity_tables_repack_timer [String] The Systemd timer for the pg_repack job affecting the 'activity' tables
# @param facts_tables_repack_enabled [Boolean] true or false (Default: true)
#   Enable or disable the pg_repack job for the 'facts' tables
# @param catalogs_tables_repack_enabled [Boolean] true or false (Default: true)
#   Enable or disable the pg_repack job for the 'catalog' tables
# @param other_tables_repack_enabled [Boolean] true or false (Default: true)
#   Enable or disable the pg_repack job for the 'other' tables
# @param activity_tables_repack_enabled [Boolean] true or false (Default: true)
#   Enable or disable the pg_repack job for the 'activity' tables
# @param reports_tables_repack_timer [String] Deprecated Parameter will be removed in future releases
# @param resource_events_tables_repack_timer [String] Deprecated Parameter will be removed in future releases
class pe_databases::pg_repack (
  # Provided by module data
  Array $fact_tables,
  Array $catalog_tables,
  Array $other_tables,
  Array $activity_tables,
  Boolean $disable_maintenance = false,
  Enum['INFO','NOTICE','WARNING','ERROR','LOG','FATAL','PANIC','DEBUG'] $repack_log_level='DEBUG',
  Boolean $enable_echo = true,
  Boolean $kill_backend = true,
  Optional[Integer[1]] $wait_timeout = undef,
  Pe_databases::Timespan $max_runtime = '12h',
  Pe_databases::Timespan $stop_timeout = '10min',
  Integer $jobs = $facts['processors']['count'] / 4,
  String[1] $facts_tables_repack_timer = $pe_databases::facts_tables_repack_timer,
  String[1] $catalogs_tables_repack_timer = $pe_databases::catalogs_tables_repack_timer,
  String[1] $other_tables_repack_timer = $pe_databases::other_tables_repack_timer,
  String[1] $activity_tables_repack_timer = $pe_databases::activity_tables_repack_timer,
  Boolean $facts_tables_repack_enabled = true,
  Boolean $catalogs_tables_repack_enabled = true,
  Boolean $other_tables_repack_enabled = true,
  Boolean $activity_tables_repack_enabled = true,
  Optional[String] $reports_tables_repack_timer = undef,
  Optional[String] $resource_events_tables_repack_timer = undef,
) {
  puppet_enterprise::deprecated_parameter { 'pe_databases::pg_repack::reports_tables_repack_timer': }
  puppet_enterprise::deprecated_parameter { 'pe_databases::pg_repack::resource_events_tables_repack_timer': }

  $postgresql_version = $facts['pe_postgresql_info']['installed_server_version']
  $repack_executable = "/opt/puppetlabs/server/apps/postgresql/${postgresql_version}/bin/pg_repack"

  if $enable_echo {
    $base_cmd = "${repack_executable} --jobs ${jobs} --elevel ${repack_log_level} --echo"
  } else {
    $base_cmd = "${repack_executable} --jobs ${jobs} --elevel ${repack_log_level}"
  }

  $kill_backend_flag = $kill_backend ? {
    true    => '',
    default => ' --no-kill-backend',
  }

  $wait_timeout_flag = $wait_timeout ? {
    undef   => '',
    default => " -T ${wait_timeout}",
  }

  $repack_cmd = "${base_cmd}${kill_backend_flag}${wait_timeout_flag}"

  file { "${pe_databases::scripts_dir}/repack_cleanup.sh":
    ensure => file,
    owner  => 'root',
    group  => 'root',
    source => 'puppet:///modules/pe_databases/repack_cleanup.sh',
    mode   => '0755',
  }

  file { "${pe_databases::scripts_dir}/repack_run.sh":
    ensure => file,
    owner  => 'root',
    group  => 'root',
    source => 'puppet:///modules/pe_databases/repack_run.sh',
    mode   => '0755',
  }

  [
    File["${pe_databases::scripts_dir}/repack_cleanup.sh"],
    File["${pe_databases::scripts_dir}/repack_run.sh"],
  ] -> Pe_databases::Collect <| |>

  pe_databases::collect { 'facts':
    disable_maintenance => $disable_maintenance or ! $facts_tables_repack_enabled,
    command             => "${repack_cmd} -d pe-puppetdb",
    database            => 'pe-puppetdb',
    max_runtime         => $max_runtime,
    stop_timeout        => $stop_timeout,
    sibling_units       => ['pe_databases-catalogs.service', 'pe_databases-other.service'],
    on_cal              => $facts_tables_repack_timer,
    tables              => $fact_tables,
  }

  pe_databases::collect { 'catalogs':
    disable_maintenance => $disable_maintenance or ! $catalogs_tables_repack_enabled,
    command             => "${repack_cmd} -d pe-puppetdb",
    database            => 'pe-puppetdb',
    max_runtime         => $max_runtime,
    stop_timeout        => $stop_timeout,
    sibling_units       => ['pe_databases-facts.service', 'pe_databases-other.service'],
    on_cal              => $catalogs_tables_repack_timer,
    tables              => $catalog_tables,
  }

  pe_databases::collect { 'other':
    disable_maintenance => $disable_maintenance or ! $other_tables_repack_enabled,
    command             => "${repack_cmd} -d pe-puppetdb",
    database            => 'pe-puppetdb',
    max_runtime         => $max_runtime,
    stop_timeout        => $stop_timeout,
    sibling_units       => ['pe_databases-facts.service', 'pe_databases-catalogs.service'],
    on_cal              => $other_tables_repack_timer,
    tables              => $other_tables,
  }

  pe_databases::collect { 'activity':
    disable_maintenance => $disable_maintenance or ! $activity_tables_repack_enabled,
    command             => "${repack_cmd} -d pe-activity",
    database            => 'pe-activity',
    max_runtime         => $max_runtime,
    stop_timeout        => $stop_timeout,
    sibling_units       => [],
    on_cal              => $activity_tables_repack_timer,
    tables              => $activity_tables,
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
