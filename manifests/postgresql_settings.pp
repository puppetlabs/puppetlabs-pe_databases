# Tune PostgreSQL
#
# @summary 
#   Tune PostgreSQL settings 
# 
# @param maintenance_work_mem [String] Increase to improve speed of speed of vacuuming and reindexing (Example "1GB")
# @param work_mem [String] Allows PostgreSQL to do larger in-memory sorts (Default: "4MB")
# @param autovacuum_work_mem [String] Similar to but for maintenance_work_mem autovacuum processes only (Example "256MB")
# @param autovacuum_max_workers [Integer] Maximum number of autovacuum processes to run concurrently (Default: 3)
# 
class pe_databases::postgresql_settings (
  Float[0,1] $autovacuum_vacuum_scale_factor                    = $pe_databases::autovacuum_vacuum_scale_factor,
  Float[0,1] $autovacuum_analyze_scale_factor                   = $pe_databases::autovacuum_analyze_scale_factor,
  Integer    $autovacuum_max_workers                            = $pe_databases::autovacuum_max_workers,
  Integer    $log_autovacuum_min_duration                       = $pe_databases::log_autovacuum_min_duration,
  Integer    $log_temp_files                                    = $pe_databases::log_temp_files,
  String     $work_mem                                          = $pe_databases::work_mem,
  Integer    $max_connections                                   = $pe_databases::max_connections,
  Hash       $arbitrary_postgresql_conf_settings                = $pe_databases::arbitrary_postgresql_conf_settings,
  Float[0,1] $checkpoint_completion_target                      = $pe_databases::checkpoint_completion_target,
  Integer    $checkpoint_segments                               = $pe_databases::checkpoint_segments,
  Boolean    $manage_postgresql_service                         = $pe_databases::manage_postgresql_service,
  Boolean    $all_in_one_pe_install                             = $pe_databases::all_in_one_pe_install,
  Boolean    $manage_reports_autovacuum_cost_delay              = $pe_databases::manage_reports_autovacuum_cost_delay,
  Optional[Float[0,1]] $factsets_autovacuum_vacuum_scale_factor = $pe_databases::factsets_autovacuum_vacuum_scale_factor,
  Optional[Float[0,1]] $reports_autovacuum_vacuum_scale_factor  = $pe_databases::reports_autovacuum_vacuum_scale_factor,
  String     $maintenance_work_mem                              = $pe_databases::maintenance_work_mem,
  String     $autovacuum_work_mem                               = $pe_databases::autovacuum_work_mem,
  String     $psql_version                                      = $pe_databases::psql_version,
) {
  $postgresql_service_resource_name = 'postgresqld'
  $postgresql_service_name          = 'pe-postgresql'
  $notify_postgresql_service        = $manage_postgresql_service ? {
    true    => Service[$postgresql_service_resource_name],
    default => undef,
  }
  $notify_console_services          = $all_in_one_pe_install ? {
    true    => Service['pe-console-services'],
    default => undef,
  }

  if $manage_postgresql_service {
    service { $postgresql_service_resource_name :
      ensure => running,
      name   => $postgresql_service_name,
      enable => true,
      notify => $notify_console_services,
    }
  }

  # The value attribute of postgresql_conf requires a string despite validating a float above.
  # https://tickets.puppetlabs.com/browse/MODULES-2960
  # http://www.postgresql.org/docs/9.4/static/runtime-config-autovacuum.html

  Pe_postgresql_conf {
    ensure => present,
    target => "/opt/puppetlabs/server/data/postgresql/${psql_version}/data/postgresql.conf",
    notify => $notify_postgresql_service,
  }

  pe_postgresql_conf { 'autovacuum_vacuum_scale_factor' :
    value => sprintf('%#.2f', $autovacuum_vacuum_scale_factor),
  }

  pe_postgresql_conf { 'autovacuum_analyze_scale_factor' :
    value => sprintf('%#.2f', $autovacuum_analyze_scale_factor),
  }

  pe_postgresql_conf { 'autovacuum_max_workers' :
    value => String($autovacuum_max_workers),
  }

  pe_postgresql_conf { 'autovacuum_work_mem' :
    value => String($autovacuum_work_mem),
  }

  pe_postgresql_conf { 'log_autovacuum_min_duration' :
    value => String($log_autovacuum_min_duration),
  }

  pe_postgresql_conf { 'log_temp_files' :
    value => String($log_temp_files),
  }

  pe_postgresql_conf { 'maintenance_work_mem' :
    value => String($maintenance_work_mem),
  }

  pe_postgresql_conf { 'work_mem' :
    value => String($work_mem),
  }

  pe_postgresql_conf { 'max_connections' :
    value => String($max_connections),
  }

  pe_postgresql_conf { 'checkpoint_completion_target' :
    value => sprintf('%#.2f', $checkpoint_completion_target),
  }

  $checkpoint_segments_ensure = $psql_version ? {
    '9.4'   => 'present',
    default => 'absent',
  }

  pe_postgresql_conf { 'checkpoint_segments' :
    ensure => $checkpoint_segments_ensure,
    value  => String($checkpoint_segments),
  }

  if !empty($arbitrary_postgresql_conf_settings) {
    $arbitrary_postgresql_conf_settings.each | $key, $value | {
      pe_postgresql_conf { $key :
        value => String($value),
      }
    }
  }
}
