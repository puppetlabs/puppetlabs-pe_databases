# @summary Tuning, maintenance for PE PostgreSQL.
# 
# @param manage_database_maintenance [Boolean] true or false (Default: true)
#   Manage the inclusion of the pg_repack class
# @param disable_maintenance [Boolean] true or false (Default: false)
#   Disable or enable maintenance mode
# @param manage_postgresql_settings [Boolean] true or false (Default: true)
#   Manage PostgreSQL settings
# @param manage_table_settings [Boolean] true or false (Default: false)
#   Manage table settings
# @param install_dir [String] Directory to install module into (Default: "/opt/puppetlabs/pe_databases")
# @param scripts_dir [String] Directory to install scripts into (Default: "${install_dir}/scripts")
class pe_databases (
  Boolean $manage_database_maintenance = true,
  Boolean $disable_maintenance         = false,
  Boolean $manage_postgresql_settings  = true,
  Boolean $manage_table_settings       = false,
  String  $install_dir                 = '/opt/puppetlabs/pe_databases',
  String  $scripts_dir                 = "${install_dir}/scripts"
) {
  $psql_version = $facts['pe_postgresql_info']['installed_server_version'] ? {
    undef   => undef,
    default => String($facts['pe_postgresql_info']['installed_server_version'])
  }

  file { [$install_dir, $scripts_dir]:
    ensure => directory,
    mode   => '0755',
  }

  exec { 'pe_databases_daemon_reload':
    command     => 'systemctl daemon-reload',
    path        => ['/bin', '/usr/bin'],
    refreshonly => true,
  }

  if $facts.dig('pe_databases', 'have_systemd') {
    if versioncmp('2019.0.2', $facts['pe_server_version']) <= 0 {
      if $manage_database_maintenance {
        class { 'pe_databases::pg_repack':
          disable_maintenance => $disable_maintenance,
        }
        if $manage_table_settings {
          # This is to provide for situations, like PE XL,
          # where the pe-puppetdb database does not exist on the PostgreSQL system being tuned.
          # In PE XL, the Primary and Replica run PostgreSQL for all databases *except* for pe-puppetdb.
          include pe_databases::postgresql_settings::table_settings
        }
      }
    }
    else {
      notify { 'pe_databases_version_warn':
        message  => 'This module only supports PE 2019.0.2 and later',
        loglevel => warning,
      }
    }
  }
  else {
    notify { 'pe_databases_systemd_warn':
      message  => 'This module only works with systemd as the provider',
      loglevel => warning,
    }
  }
}
