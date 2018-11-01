class pe_databases (
  Boolean $manage_database_backups     = true,
  Boolean $manage_database_maintenance = true,
  Boolean $manage_postgresql_settings  = true,
  Boolean $manage_table_settings       = true,
  String  $install_dir                 = '/opt/puppetlabs/pe_databases',
  String  $scripts_dir                 = "${install_dir}/scripts"
) {

  if ( versioncmp('2017.3.0', $facts['pe_server_version']) <= 0 ) {
    $psql_version = '9.6'
  } else {
    $psql_version = '9.4'
  }

  file { [$install_dir, $scripts_dir] :
    ensure => directory,
    mode   => '0755',
  }

  if $manage_database_maintenance {
    include pe_databases::maintenance
  }

  if $manage_postgresql_settings and ( versioncmp('2018.1.0', $facts['pe_server_version']) > 0 ) {
    include pe_databases::postgresql_settings

    class { 'pe_databases::postgresql_settings::table_settings' :
      manage_fact_values_autovacuum_cost_delay => $pe_databases::postgresql_settings::manage_fact_values_autovacuum_cost_delay,
      manage_reports_autovacuum_cost_delay     => $pe_databases::postgresql_settings::manage_reports_autovacuum_cost_delay,
      factsets_autovacuum_vacuum_scale_factor  => $pe_databases::postgresql_settings::factsets_autovacuum_vacuum_scale_factor,
      reports_autovacuum_vacuum_scale_factor   => $pe_databases::postgresql_settings::reports_autovacuum_vacuum_scale_factor,
      require                                  => Class['pe_databases::postgresql_settings'],
    }
  } elsif $manage_table_settings { #do not manage postgreql_settings in 2018.1.0
    include pe_databases::postgresql_settings::table_settings
  }

  if $manage_database_backups {
    include pe_databases::backup
  }
}
