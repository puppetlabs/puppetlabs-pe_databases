define pe_databases::backup (
  $db_name          = $title,
  $pg_dump_command  = '/opt/puppetlabs/server/bin/pg_dump -Fc''  
  $dump_path        = '/opt/puppetlabs/server/data/postgresql/9.4/backups/',
  $script_directory = '/usr/local/bin',
  $minute           = '30',
  $hour             = '23',
  $monthday         = '*',
) {

  validate_string($pg_dump_command)
  validate_absolute_path($dump_path)
  validate_absolute_path($script_directory)
  validate_string($minute)
  validate_string($hour)
  validate_string($monthday)

  file { "${script_directory}/dump_${db_name}.sh":
    ensure  => file,
    content => template('pe_databases/backup/db_dump.sh.erb'),
    owner   => 'pe-postgres',
    group   => 'pe-postgres',
    mode    => '0750',
    before  => Cron["${db_name}_db_dump"],
  }

  cron { "${db_name}_db_dump":
    ensure   => present,
    command  => "${script_directory}/dump_${db_name}.sh",
    user     => 'pe-postgres',
    minute   => $minute,
    hour     => $hour,
    monthday => $monthday,
    require  => File['dump_directory'],
  }

}
