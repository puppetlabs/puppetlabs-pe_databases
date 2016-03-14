class pe_databases (
  Array[String] $databases_to_backup   = [ 'pe-activity', 'pe-classifier', 'pe-postgres', 'pe-puppetdb', 'pe-rbac', 'pe-orchestrator' ],
  Boolean $manage_database_maintenance = true,
  Boolean $manage_postgresql_settings  = true,
) {

  if $manage_database_maintenance {
    include pe_databases::maintenance
  }

  if $manage_postgresql_settings {
    include pe_databases::postgresql_settings
  }

  if !empty($databases_to_backup) {
    $databases_to_backup.each | String $db | {
      pe_databases::backup{ $db :}
    }
  }
}
