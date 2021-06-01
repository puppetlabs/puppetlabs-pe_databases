# Tuning, maintenance, and backups for PE PostgreSQL.
#
# @summary Tuning, maintenance, and backups for PE PostgreSQL.

class pe_databases (
  Boolean $manage_database_backups     = false,
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

  exec { 'pe_databases_daemon_reload':
    command     => 'systemctl daemon-reload',
    path        => ['/bin', '/usr/bin'],
    refreshonly => true,
  }

  if $facts.dig('pe_databases', 'have_systemd') {
    if $manage_database_maintenance and (versioncmp('2019.0.2', $facts['pe_server_version']) <= 0) {
      class {'pe_databases::pg_repack':
        disable_maintenance => lookup('pe_databases::maintenance::disable_maintenance', {'default_value' => false}),
      }
      if $manage_table_settings {
        # This is to provide for situations, like PE XL,
        # where the pe-puppetdb database does not exist on the PostgreSQL system being tuned.
        # In PE XL, the Master and Replica run PostgreSQL for all databases *except* for pe-puppetdb.
        include pe_databases::postgresql_settings::table_settings
      }

      if $manage_database_backups {
        include pe_databases::backup
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
