# Create systemd units for repacking a given database type
# @param database_type [String] The database to repack, uses titles from pg_repack.pp
# @param command [String] defined in pg_repack.pp
# @param disable_maintenance [Boolean] to disable maintenance mode (Default: false)
# @param on_cal [String] values can be found in pg_repack.pp
# @param tables [Array] Array of tables to repack
# @param database [Pe_databases::Database_name] The database the job repacks, passed to the cleanup script
# @param max_runtime [Pe_databases::Timespan] Maximum time the service may run before systemd stops it (the TimeoutStartSec value)
# @param stop_timeout [Pe_databases::Timespan] Maximum time systemd waits for a stopping job, including pg_repack's abort and the
#   cleanup, before it kills it (the TimeoutStopSec value)
# @param cleanup_script [String[1]] Path to the script that clears leftover pg_repack objects before and after each run
# @param wrapper_script [String[1]] Path to the script that runs the cleanup and pg_repack commands for each job
# @param sibling_units [Array[String[1]]] Names of systemd units for other jobs on the same database that the cleanup script
#   checks for before it removes leftover objects
define pe_databases::collect (
  String  $database_type       = $title,
  String  $command             = undef,
  Boolean $disable_maintenance = false,
  String  $on_cal              = undef,
  Array   $tables              = undef,
  Pe_databases::Database_name $database = 'pe-puppetdb',
  Pe_databases::Timespan $max_runtime = '12h',
  Pe_databases::Timespan $stop_timeout = '10min',
  String[1] $cleanup_script    = "${pe_databases::scripts_dir}/repack_cleanup.sh",
  String[1] $wrapper_script    = "${pe_databases::scripts_dir}/repack_run.sh",
  Array[String[1]] $sibling_units = [],
) {
  Service {
    notify  => Exec['pe_databases_daemon_reload'],
  }
  File {
    notify  => Exec['pe_databases_daemon_reload'],
  }

  $ensure_service = $disable_maintenance ? {
    true  => stopped,
    default => running,
  }

  $ensure_file = $disable_maintenance ? {
    true    => absent,
    default => present
  }

  $tables_command = $tables.map |$table| { "-t ${table}" }.join(' ')

  $repack_command = "${command} ${tables_command}"

  $siblings_arg = $sibling_units.empty ? {
    true    => '',
    default => " --siblings ${sibling_units.join(',')}",
  }

  $tables_arg = $tables.empty ? {
    true    => '',
    default => " ${tables.join(' ')}",
  }

  $cleanup_command = "${cleanup_script}${siblings_arg} ${database}${tables_arg}"

  $service_params = {
    'tables'          => $database_type,
    'command'         => $repack_command,
    'max_runtime'     => $max_runtime,
    'cleanup_command' => $cleanup_command,
    'stop_timeout'    => $stop_timeout,
    'wrapper_command' => $wrapper_script,
  }

  file { "/etc/systemd/system/pe_databases-${database_type}.service":
    ensure  => $ensure_file,
    content => epp('pe_databases/service.epp', $service_params),
  }
  file { "/etc/systemd/system/pe_databases-${database_type}.timer":
    ensure  => $ensure_file,
    content => epp('pe_databases/timer.epp', { 'tables' => $database_type, 'on_cal' => $on_cal }),
  }

  service { "pe_databases-${database_type}.service": }
  service { "pe_databases-${database_type}.timer":
    ensure    => $ensure_service,
    enable    => ! $disable_maintenance,
    subscribe => File["/etc/systemd/system/pe_databases-${database_type}.timer"],
  }
}
