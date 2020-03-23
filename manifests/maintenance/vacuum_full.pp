# Maintenance VACUUM FULL
#
# @summary Maintenance VACUUM FULL

class pe_databases::maintenance::vacuum_full (
  Boolean $disable_maintenance = $pe_databases::maintenance::disable_maintenance,
  String  $logging_directory   = $pe_databases::maintenance::logging_directory,
  String  $script_directory    = $pe_databases::maintenance::script_directory,
){

  $ensure_cron = $disable_maintenance ? {
    true    => absent,
    default => present
  }

  $ensure_vacuum_script = $disable_maintenance ? {
    true    => absent,
    default => file
  }

  $vacuum_script_path = "${script_directory}/vacuum_full_tables.sh"

  file { $vacuum_script_path:
    ensure => $ensure_vacuum_script,
    source => 'puppet:///modules/pe_databases/vacuum_full_tables.sh',
    owner  => 'pe-postgres',
    group  => 'pe-postgres',
    mode   => '0744',
  }

  Cron {
    ensure  => $ensure_cron,
    user    => 'root',
    require => File[$logging_directory, $script_directory],
  }

  cron { 'VACUUM FULL facts tables' :
    weekday => [2,6],
    hour    => 4,
    minute  => 30,
    command => "${vacuum_script_path} facts",
  }

  cron { 'VACUUM FULL catalogs tables' :
    weekday => [0,4],
    hour    => 4,
    minute  => 30,
    command => "${vacuum_script_path} catalogs",
  }

  cron { 'VACUUM FULL other tables' :
    monthday => 20,
    hour     => 5,
    minute   => 30,
    command  => "${vacuum_script_path} other",
  }

  # LEGACY CLEANUP

  # lint:ignore:140chars
  cron { 'Maintain PE databases' :
    ensure  => absent,
    user    => 'root',
    command => "su - pe-postgres -s /bin/bash -c '/opt/puppetlabs/server/bin/reindexdb --all; /opt/puppetlabs/server/bin/vacuumdb --analyze --verbose --all' > ${logging_directory}/output.log 2> ${logging_directory}/output_error.log",
    require => File[$logging_directory, $script_directory],
  }
  # lint:endignore
}
