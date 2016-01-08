class pe_databases::maintenance (
  Boolean $disable_maintenace = false,
  $maint_cron_weekday         = 6,
  $maint_cron_hour            = 1,
  $maint_cron_minute          = 0,
  $logging_directory          = '/var/log/puppetlabs/pe_databases_cron'
){

  $ensure_cron = $disable_maintenace ? {
    true    => absent,
    default => present
  }

  file { $logging_directory :
    ensure => directory,
  }

  cron { 'Maintain PE databases' :
    ensure  => $ensure_cron,
    user    => 'root',
    weekday => $maint_cron_weekday,
    hour    => $maint_cron_hour,
    minute  => $maint_cron_minute,
    command => "su - pe-postgres -s /bin/bash -c '/opt/puppetlabs/server/bin/reindexdb --all; /opt/puppetlabs/server/bin/vacuumdb --analyze --verbose --all' > ${logging_directory}/output.log 2> ${logging_directory}/output_error.log",
    require => File[$logging_directory],
  }

}
