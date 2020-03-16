# Tuning, maintenance, and backups for PE PostgreSQL.
#
# @summary Tuning, maintenance, and backups for PE PostgreSQL.

class pe_databases (
  Boolean $manage_database_backups     = true,
  Boolean $manage_database_maintenance = true,
  Boolean $manage_postgresql_settings  = true,
  Boolean $manage_table_settings       = true,
  String  $install_dir                 = '/opt/puppetlabs/pe_databases',
  String  $scripts_dir                 = "${install_dir}/scripts"
) {

  $psql_version = $facts['pe_postgresql_info']['installed_server_version'] ? {
    undef   => undef,
    default => String($facts['pe_postgresql_info']['installed_server_version'])
  }

  file { [$install_dir, $scripts_dir] :
    ensure => directory,
    mode   => '0755',
  }

  if $manage_database_maintenance {
    include pe_databases::maintenance
  }

  # Do not manage postgresql_settings in 2018.1.0 or newer.
  if $manage_postgresql_settings and (versioncmp('2018.1.0', $facts['pe_server_version']) > 0) {
    include pe_databases::postgresql_settings
    class { 'pe_databases::postgresql_settings::table_settings' :
      manage_reports_autovacuum_cost_delay     => $pe_databases::postgresql_settings::manage_reports_autovacuum_cost_delay,
      factsets_autovacuum_vacuum_scale_factor  => $pe_databases::postgresql_settings::factsets_autovacuum_vacuum_scale_factor,
      reports_autovacuum_vacuum_scale_factor   => $pe_databases::postgresql_settings::reports_autovacuum_vacuum_scale_factor,
      require                                  => Class['pe_databases::postgresql_settings'],
    }
  } elsif $manage_table_settings {
    # This is to provide for situations, like PE XL,
    # where the pe-puppetdb database does not exist on the PostgreSQL system being tuned.
    # In PE XL, the Master and Replica run PostgreSQL for all databases *except* for pe-puppetdb.
    include pe_databases::postgresql_settings::table_settings
  }

  if $manage_database_backups {
    include pe_databases::backup
  }
}
