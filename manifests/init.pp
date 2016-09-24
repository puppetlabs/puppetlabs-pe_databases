class pe_databases (
  Boolean $manage_database_backups     = true,
  Boolean $manage_database_maintenance = true,
  Boolean $manage_postgresql_settings  = true,
) {

  if $manage_database_maintenance {
    include pe_databases::maintenance
  }

  if $manage_postgresql_settings {
    include pe_databases::postgresql_settings
  }

  if $manage_database_backups {
    include pe_databases::backup
  }
}
