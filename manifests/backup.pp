define pe_databases::backup (
  Array[String] $databases_to_backup = [ 'pe-activity', 'pe-classifier', 'pe-postgres', 'pe-puppetdb', 'pe-rbac', 'pe-orchestrator' ],
  String $minute                     = '30',
  String $hour                       = '23',
  String $weekday                    = '*',
) {

  $db_string = join($databases_to_backup, " ")

  cron { "puppet_enterprise_database_backup_${databases_to_backup}":
    ensure  => present,
    command => "${pe_databases::backup_script_path} -l ${pe_databases::backup_logging_directory} -t ${pe_databases::backup_directory} ${db_string}",
    user    => 'pe-postgres',
    minute  => $minute,
    hour    => $hour,
    weekday => $weekday,
    require => File['puppet_enterprise_db_backup_script'],
  }
}
