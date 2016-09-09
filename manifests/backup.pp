define pe_databases::backup (
  Array[String] $databases_to_backup = [ 'pe-activity', 'pe-classifier', 'pe-postgres', 'pe-puppetdb', 'pe-rbac', 'pe-orchestrator' ],
  String $backup_directory           = '/opt/puppetlabs/server/data/postgresql/9.4/backups',
  String $script_directory           = '/opt/puppetlabs/pe_databases/scripts',
  String $minute                     = '30',
  String $hour                       = '23',
  String $weekday                    = '*',
  String $logging_directory          = '/var/log/puppetlabs/pe_databases_backup',
) {

  ensure_resource( 'file', [ '/opt/puppetlabs/pe_databases', $script_directory, $backup_directory ],
    { 'ensure' => 'directory' }
  )

  ensure_resource( 'file', $logging_directory,
    { 'ensure' => 'directory',
       'owner' => 'pe-postgres',
       'group' => 'pe-postgres', }
  )

  $script_path = "${script_directory}/puppet_enterprise_database_${databases_to_backup}_backup.sh"

  file { $script_path :
    ensure  => file,
    content => epp('pe_databases/puppet_enterprise_database_backup.sh.epp',
                   { databases_to_backup => $databases_to_backup,
                     logging_directory   => $logging_directory,
                     backup_directory    => $backup_directory,
                   }),
    owner   => 'pe-postgres',
    group   => 'pe-postgres',
    mode    => '0750',
    before  => Cron["puppet_enterprise_database_backup_${databases_to_backup}"],
  }

  cron { "puppet_enterprise_database_backup_${databases_to_backup}":
    ensure   => present,
    command  => $script_path,
    user     => 'pe-postgres',
    minute   => $minute,
    hour     => $hour,
    weekday  => $weekday,
  }
}
