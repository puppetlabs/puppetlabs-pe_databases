define pe_databases::set_table_attribute (
  String $db,
  String $table_name,
  String $table_attribute,
  String $table_attribute_value,
) {

  postgresql_psql { "Set ${table_attribute}=${table_attribute_value} for ${table_name}" :
      command    => "ALTER TABLE ${table_name} SET ( ${table_attribute} = 0 )",
      unless     => "SELECT reloptions FROM pg_class WHERE relname = '${table_name}' AND CAST(reloptions as text) LIKE '%${table_attribute}=${table_attribute_value}%'",
      db         => $db,
      psql_user  => 'pe-postgres',
      psql_group => 'pe-postgres',
      psql_path  => '/opt/puppetlabs/server/bin/psql',
    }
}
