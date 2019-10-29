# A description of what this class does
#
# @summary A short summary of the purpose of this class
#
# @example
#   include pe_databases::maintenance::manage_resource_events
class pe_databases::maintenance::manage_resource_events (
  Boolean $disable_maintenance = $pe_databases::maintenance::disable_maintenance,
  Integer $resource_events_ttl = $pe_databases::maintenance::resource_events_ttl,
  String  $script_directory    = $pe_databases::maintenance::script_directory,
  String  $logging_directory   = $pe_databases::maintenance::logging_directory,
){

  $absent = ($disable_maintenance or $resource_events_ttl == 0)

  $ensure_cron = $absent ? {
    true    => absent,
    default => present
  }

  $ensure_delete_script = $absent ? {
    true    => absent,
    default => file
  }

  $delete_script_path = "${script_directory}/delete_from_resource_events.sh"

  file { $delete_script_path:
    ensure => $ensure_delete_script,
    source => 'puppet:///modules/pe_databases/delete_from_resource_events.sh',
    owner  => 'pe-postgres',
    group  => 'pe-postgres',
    mode   => '0744',
  }

  cron { 'DELETE FROM resource_events' :
    ensure   => $ensure_cron,
    user     => 'root',
    hour     => 4,
    minute   => 15,
    command  => "${delete_script_path} ${resource_events_ttl} > ${logging_directory}/output.log 2>&1",
    require  => File[$logging_directory, $script_directory],
  }

}
