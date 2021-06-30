# Backup PostgreSQL
#
# @summary Backup PostgreSQL

class pe_databases::backup (
  Array[Hash] $databases_and_backup_schedule =
  [
    {
      'databases' => pe_databases::version_based_databases(),
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
  String  $psql_version             = $pe_databases::psql_version,
  String  $backup_directory         = "/opt/puppetlabs/server/data/postgresql/${psql_version}/backups",
  String  $backup_script_path       = "${pe_databases::scripts_dir}/puppet_enterprise_database_backup.sh",
  String  $daily_databases_path     = "${pe_databases::install_dir}/default_daily_databases.txt",
  String  $backup_logging_directory = '/var/log/puppetlabs/pe_databases_backup',
  Integer $retention_policy         = 2,
) {

  file { $backup_logging_directory :
    ensure => 'directory',
    owner  => 'pe-postgres',
    group  => 'pe-postgres',
  }

  file { 'pe_databases_backup_script' :
    ensure => file,
    owner  => 'pe-postgres',
    group  => 'pe-postgres',
    mode   => '0750',
    path   => $backup_script_path,
    source => 'puppet:///modules/pe_databases/puppet_enterprise_database_backup.sh',
  }

  # Track the (databases backed up by default every day).
  file { 'pe_databases_default_daily_databases' :
    ensure  => 'file',
    path    => $daily_databases_path,
    content => "${pe_databases::version_based_databases()}",
    notify  => Exec['reset_pe-postgres_crontab'],
  }

  # Reset the crontab for pe-postgres if the (databases backed up by default every day) change.
  exec { 'reset_pe-postgres_crontab':
    path        => '/usr/local/bin/:/bin/:/usr/bin',
    command     => 'crontab -r -u pe-postgres',
    onlyif      => 'crontab -l -u pe-postgres',
    refreshonly => true,
  }

  # Since the cron job titles below include the array ('databases') of database names,
  # the crontab for pe-postgres needs to be reset if the array of database names changes,
  # otherwise the change create a new cron job and unmanage the old cron job.

  # TODO: This takes two runs to become idempotent. Why?

  $databases_and_backup_schedule.each | Hash $database_backup_set | {
    $databases_to_backup = $database_backup_set['databases']
    $databases = join($databases_to_backup, ' ')
    cron { "puppet_enterprise_database_backup_${databases_to_backup}":
      ensure  => present,
      command => "${backup_script_path} -l ${backup_logging_directory} -t ${backup_directory} -r ${retention_policy} ${databases}",
      user    => 'pe-postgres',
      minute  => $database_backup_set['schedule']['minute'],
      hour    => $database_backup_set['schedule']['hour'],
      weekday => $database_backup_set['schedule']['weekday'],
      require => [File['pe_databases_backup_script'], File['pe_databases_default_daily_databases']],
    }
  }
}
