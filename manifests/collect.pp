# Create systemd units for repacking a given database type
define pe_databases::collect (
  String  $database_type       = $title,
  String  $command             = undef,
  Boolean $disable_maintenance = false,
  String  $on_cal              = undef,
) {

  Service {
    notify  => Exec['pe_databases_daemon_reload'],
  }
  File {
    notify  => Exec['pe_databases_daemon_reload'],
  }

  $ensure_service = $disable_maintenance ? {
    true  => stopped,
    default => running,
  }

  $ensure_file = $disable_maintenance ? {
    true    => absent,
    default => present
  }

  file {"/etc/systemd/system/pe_databases-${database_type}.service":
    ensure  => $ensure_file,
    content => epp('pe_databases/service.epp', { 'tables' => $database_type, 'command' => $command }),
  }
  file {"/etc/systemd/system/pe_databases-${database_type}.timer":
    ensure  => $ensure_file,
    content => epp('pe_databases/timer.epp', { 'tables' => $database_type, 'on_cal' => $on_cal }),
  }

  service { "pe_databases-${database_type}.service": }
  service { "pe_databases-${database_type}.timer":
    ensure    => $ensure_service,
    enable    => ! $disable_maintenance,
    subscribe => File["/etc/systemd/system/pe_databases-${database_type}.timer"],
  }
}
