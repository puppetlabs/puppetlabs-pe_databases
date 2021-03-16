# Maintenance for PostgreSQL
#
# @summary Maintenance for PostgreSQL

class pe_databases::maintenance (
  Boolean $disable_maintenance = false,
  Boolean $disable_logrotate   = false,
  String  $logging_directory   = '/var/log/puppetlabs/pe_databases_cron',
  String  $log_level           = 'debug',
  String  $script_directory    = $pe_databases::scripts_dir,
){

  # If this version of PE includes pg_repack (2018.1.7 and 2019.0.2 and newer),
  # then use pg_repack and remove the old script and cron jobs.

  if (versioncmp( '2018.1.7', $facts['pe_server_version']) <= 0 and versioncmp($facts['pe_server_version'], '2019.0.0') < 0 ) {
    include pe_databases::maintenance::pg_repack
    class { 'pe_databases::maintenance::vacuum_full':
      disable_maintenance => true,
    }
  } elsif ( versioncmp( '2019.0.2', $facts['pe_server_version']) <= 0 ) {
    include pe_databases::maintenance::pg_repack
    class { 'pe_databases::maintenance::vacuum_full':
      disable_maintenance => true,
    }
  } else {
    include pe_databases::maintenance::vacuum_full
  }

  file { $logging_directory :
    ensure => directory,
  }

  $logrotate_ensure = $disable_logrotate ? {
    true    => 'absent',
    default =>  'file'
  }

  file { '/etc/logrotate.d/pe_databases' :
    ensure  => $logrotate_ensure,
    content => epp('pe_databases/logrotate.epp', { 'logging_directory' => $logging_directory })
  }
}
