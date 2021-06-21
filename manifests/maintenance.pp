# Maintenance for PostgreSQL
#
# @summary Maintenance for PostgreSQL

class pe_databases::maintenance (
  Boolean $disable_maintenance = false,
  String  $logging_directory   = '/var/log/puppetlabs/pe_databases_cron',
  String  $script_directory    = $pe_databases::scripts_dir,
  Boolean $use_pg_repack       = pe_databases::has_pg_repack_available(),
){

  # If this version of PE includes pg_repack (2018.1.7 and 2019.0.2 and newer),
  # then use pg_repack and remove the old script and cron jobs.
  # If the user specifies $use_pg_repack = false then use vacuum_full and
  # make sure to remove the pg_repack cron jobs and scripts

  if $use_pg_repack {
    include pe_databases::maintenance::pg_repack
    class { 'pe_databases::maintenance::vacuum_full':
      disable_maintenance => true,
    }
  } else {
    include pe_databases::maintenance::vacuum_full
    class { 'pe_databases::maintenance::pg_repack':
      disable_maintenance => true,
    }
  }

  file { $logging_directory :
    ensure => directory,
  }
}
