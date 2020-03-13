# Function: version_based_databases
#
# Results:
#
# $databases: a version-specific array of databases.

function pe_databases::version_based_databases() >> Array[String] {
  $databases = [
    'pe-activity',
    'pe-classifier',
    'pe-inventory',
    'pe-orchestrator',
    'pe-postgres',
    'pe-rbac',
  ]

  if (versioncmp($facts['pe_server_version'], '2019.0.0') < 0) {
    return $databases - ['pe-inventory']
  } else {
    return $databases
  }
}
