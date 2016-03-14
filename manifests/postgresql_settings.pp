class postgresql_settings (
  Float[0,1] $autovacuum_vacuum_scale_factor   = 0.08,
  Float[0,1] $autovacuum_analyze_scale_factor  = 0.04,
  Boolean $manage_postgresql_service           = true,
  Boolean $all_in_one_pe_install               = true,
) {

  $postgresql_service_resource_name = 'postgresqld'
  $postgresql_service_name          = 'pe-postgresql'
  $notify_postgresql_service        = $manage_postgresql_service ? {
    true    => Service[$postgresql_service_resource_name],
    default => undef,
  }
  $notify_console_services = $all_in_one_pe_install ? {
    true    => Service['pe-console-services'],
    default => undef,
  }

  if $manage_postgresql_service {
    service { $postgresql_service_resource_name :
      name   => $postgresql_service_name,
      ensure => running,
      enable => true,
      notify => $notify_console_services,
    }
  }

  #The value attribute of postgresql_conf requires a string despite validating a float above
  #https://tickets.puppetlabs.com/browse/MODULES-2960
  #http://www.postgresql.org/docs/9.4/static/runtime-config-autovacuum.html
  Postgresql_conf {
    ensure => present,
    target => '/opt/puppetlabs/server/data/postgresql/9.4/data/postgresql.conf',
    notify => $notify_postgresql_service,
  }

  postgresql_conf { 'autovacuum_vacuum_scale_factor' :
    value => "${autovacuum_vacuum_scale_factor}",
  }

  postgresql_conf { 'autovacuum_analyze_scale_factor' :
    value => "${autovacuum_analyze_scale_factor}",
  }
}
