# @summary Tuning, maintenance for PE PostgreSQL.
# 
# @param manage_database_maintenance [Boolean] true or false (Default: true)
#   Manage the inclusion of the pg_repack class
# @param disable_maintenance [Boolean] true or false (Default: false)
#   Disable or enable maintenance mode
# @param install_dir [String] Directory to install module into (Default: "/opt/puppetlabs/pe_databases")
# @param scripts_dir [String] Directory to install scripts into (Default: "${install_dir}/scripts")
# @param facts_tables_repack_timer [String] The Systemd timer for the pg_repack job affecting the 'facts' tables
# @param catalogs_tables_repack_timer [String]The Systemd timer for the pg_repack job affecting the 'catalog' tables
# @param other_tables_repack_timer [String] The Systemd timer for the pg_repack job affecting the 'other' tables
class pe_databases (
  Boolean $manage_database_maintenance           = true,
  Boolean $disable_maintenance                   = false,
  Optional[Boolean] $manage_postgresql_settings  = undef,
  Optional[Boolean] $manage_table_settings       = undef,
  String[1] $install_dir                         = '/opt/puppetlabs/pe_databases',
  String[1] $scripts_dir                         = "${install_dir}/scripts",
  String[1] $facts_tables_repack_timer           = 'Tue,Sat *-*-* 04:30:00',
  String[1] $catalogs_tables_repack_timer        = 'Sun,Thu *-*-* 04:30:00',
  String[1] $other_tables_repack_timer           = '*-*-20 05:30:00',
  Optional[String] $reports_tables_repack_timer         = undef,
  Optional[String] $resource_events_tables_repack_timer = undef,
) {
  puppet_enterprise::deprecated_parameter { 'pe_databases::manage_postgresql_settings': }
  puppet_enterprise::deprecated_parameter { 'pe_databases::manage_table_settings': }
  puppet_enterprise::deprecated_parameter { 'pe_databases::reports_tables_repack_timer': }
  puppet_enterprise::deprecated_parameter { 'pe_databases::resource_events_tables_repack_timer': }

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
    if $manage_database_maintenance {
      class { 'pe_databases::pg_repack':
        disable_maintenance => $disable_maintenance,
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
