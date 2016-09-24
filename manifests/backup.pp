class pe_databases::backup (
  Array[Hash] $databases_and_backup_schedule = [
    {
      'databases' => ['pe-activity', 'pe-classifier', 'pe-postgres', 'pe-rbac', 'pe-orchestrator'],
      'schedule'  =>
      {
        'minute' => '30',
        'hour'   => '22',
      },
    },
    {
      'databases' => ['pe-puppetdb'],
      'schedule'  =>
      {
        'minute'  => '0',
        'hour'    => '2',
        'weekday' => '7',
      },
    }
  ],
  String $backup_directory         = '/opt/puppetlabs/server/data/postgresql/9.4/backups',
  String $backup_script_path       = '/opt/puppetlabs/pe_databases/scripts/puppet_enterprise_database_backup.sh',
  String $backup_logging_directory = '/var/log/puppetlabs/pe_databases_backup',
) {

  file { ['/opt/puppetlabs/pe_databases', '/opt/puppetlabs/pe_databases/scripts', $backup_directory ] :
    ensure => directory,
  }

  file { $backup_logging_directory :
    ensure => 'directory',
    owner  => 'pe-postgres',
    group  => 'pe-postgres',
  }

  file { 'puppet_enterprise_db_backup_script' :
    ensure => file,
    owner  => 'pe-postgres',
    group  => 'pe-postgres',
    mode   => '0750',
    path   => $backup_script_path,
    source => 'puppet:///modules/pe_databases/puppet_enterprise_database_backup.sh',
  }

  $databases_and_backup_schedule.each | Hash $dbs_and_schedule | {

    $databases_to_backup = $dbs_and_schedule['databases']
    $db_string = join($databases_to_backup, ' ')

    cron { "puppet_enterprise_database_backup_${databases_to_backup}":
      ensure  => present,
      command => "${backup_script_path} -l ${backup_logging_directory} -t ${backup_directory} ${db_string}",
      user    => 'pe-postgres',
      minute  => $dbs_and_schedule['schedule']['minute'],
      hour    => $dbs_and_schedule['schedule']['hour'],
      weekday => $dbs_and_schedule['schedule']['weekday'],
      require => File['puppet_enterprise_db_backup_script'],
    }
  }
}
