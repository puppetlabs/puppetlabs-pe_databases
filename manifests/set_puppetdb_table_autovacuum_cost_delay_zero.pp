# Defined type for PostgreSQL autovacuum_cost_delay
#
# @summary 
#   Defined type for PostgreSQL autovacuum_cost_delay
# 
# @param table_name [String]
#   Name of the table
define pe_databases::set_puppetdb_table_autovacuum_cost_delay_zero (
  String $table_name = $title,
) {
  pe_databases::set_table_attribute { "Set autovacuum_cost_delay=0 for ${table_name}" :
    db                    => 'pe-puppetdb',
    table_name            => $table_name,
    table_attribute       => 'autovacuum_vacuum_cost_delay',
    table_attribute_value => '0',
  }
}
