class pe_databases (
  Array[Hash] $databases_and_backup_schedule = [
    {
      'databases' => ['pe-activity', 'pe-classifier', 'pe-postgres', 'pe-rbac', 'pe-orchestrator'],
      'schedule'  =>
      {
        'minute' => '30',
        'hour'   => '22',
      },
    },
    {
      'databases' => ['pe-puppetdb'],
      'schedule'  =>
      {
        'minute'  => '0',
        'hour'    => '2',
        'weekday' => '7',
      },
    }
  ],
  Boolean $manage_database_maintenance = true,
  Boolean $manage_postgresql_settings  = true,
) {

  if $manage_database_maintenance {
    include pe_databases::maintenance
  }

  if $manage_postgresql_settings {
    include pe_databases::postgresql_settings
  }

  if !empty($databases_and_backup_schedule) {
    $databases_and_backup_schedule.each | Hash $dbs_and_schedule | {
      pe_databases::backup{ "${dbs_and_schedule['databases']}" :
        databases_to_backup => $dbs_and_schedule['databases'],
        minute              => $dbs_and_schedule['schedule']['minute'],
        hour                => $dbs_and_schedule['schedule']['hour'],
        weekday             => $dbs_and_schedule['schedule']['weekday'],
      }
    }
  }
}
