class pe_databases::maintenance (
  Boolean $disable_maintenace = false,
  Integer $maint_cron_weekday = 6,
  Integer $maint_cron_hour    = 1,
  Integer $maint_cron_minute  = 0,
  String  $logging_directory  = '/var/log/puppetlabs/pe_databases_cron',
  String  $script_directory   = $pe_databases::scripts_dir,
){

  $ensure_cron = $disable_maintenace ? {
    true    => absent,
    default => present
  }

  file { $logging_directory :
    ensure => directory,
  }

  $vacuum_script_path = "${script_directory}/vacuum_full_tables.sh"

  file { $vacuum_script_path:
    ensure => file,
    source => 'puppet:///modules/pe_databases/vacuum_full_tables.sh',
    owner  => 'pe-postgres',
    group  => 'pe-postgres',
    mode   => '744',
  }

  cron { 'VACUUM FULL facts tables' :
    ensure   => $ensure_cron,
    user     => 'root',
    weekday => [2,6],
    hour     => 4,
    minute   => 30,
    command  => "${vacuum_script_path} facts > ${logging_directory}/facts_output.log 2>| tee ${logging_directory}/facts_error.log",
    require  => File[$logging_directory, $script_directory],
  }

  cron { 'VACUUM FULL catalogs tables' :
    ensure   => $ensure_cron,
    user     => 'root',
    weekday  => [0,4],
    hour     => 4,
    minute   => 30,
    command  => "${vacuum_script_path} catalogs > ${logging_directory}/catalogs_output.log 2>| tee ${logging_directory}/catalogs_error.log",
    require  => File[$logging_directory, $script_directory],
  }

  cron { 'VACUUM FULL other tables' :
    ensure   => $ensure_cron,
    user     => 'root',
    monthday => 20,
    hour     => 5,
    minute   => 30,
    command  => "${vacuum_script_path} other > ${logging_directory}/other_output.log 2>| tee ${logging_directory}/other_error.log",
    require  => File[$logging_directory, $script_directory],
  }

  #Remove old versions of maintenance cron jobs
  cron { 'Maintain PE databases' :
    ensure  => absent,
    user    => 'root',
    weekday => $maint_cron_weekday,
    hour    => $maint_cron_hour,
    minute  => $maint_cron_minute,
    command => "su - pe-postgres -s /bin/bash -c '/opt/puppetlabs/server/bin/reindexdb --all; /opt/puppetlabs/server/bin/vacuumdb --analyze --verbose --all' > ${logging_directory}/output.log 2> ${logging_directory}/output_error.log",
    require => File[$logging_directory, $script_directory],
  }
}
