# Function: has_pg_repack_available
#
# Results:
#
# returns true if the system has pg_repack available and false if not.

function pe_databases::has_pg_repack_available() >> Boolean {

  if (versioncmp( '2018.1.7', $facts['pe_server_version']) <= 0 and versioncmp($facts['pe_server_version'], '2019.0.0') < 0 ) {
    $has_pg_repack_available = true
  } elsif ( versioncmp( '2019.0.2', $facts['pe_server_version']) <= 0 ) {
    $has_pg_repack_available = true
  } else {
    $has_pg_repack_available = false
  }

}
