class pe_databases::postgresql_settings::table_settings (
  Boolean    $manage_fact_values_autovacuum_cost_delay = lookup('pe_databases::postgresql_settings::manage_fact_values_autovacuum_cost_delay',
                                                               {'default_value' => true}),
  Boolean    $manage_reports_autovacuum_cost_delay     = lookup('pe_databases::postgresql_settings::manage_reports_autovacuum_cost_delay',
                                                               {'default_value' => true}),
  Optional[Float[0,1]] $factsets_autovacuum_vacuum_scale_factor = lookup('pe_databases::postgresql_settings::factsets_autovacuum_vacuum_scale_factor',
                                                                        {'default_value' => 0.80}),
  Optional[Float[0,1]] $reports_autovacuum_vacuum_scale_factor  = lookup('pe_databases::postgresql_settings::reports_autovacuum_vacuum_scale_factor',
                                                                        {'default_value' => 0.01}),
  Optional[Float[0,1]] $catalogs_autovacuum_vacuum_scale_factor = 0.75,
  Optional[Float[0,1]] $certnames_autovacuum_vacuum_scale_factor = 0.75,
  Optional[Float[0,1]] $fact_paths_autovacuum_vacuum_scale_factor = 0.80,
) {

  if ( versioncmp('2017.2.0', $facts['pe_server_version']) > 0 or
       ( versioncmp('2017.3.0', $facts['pe_server_version']) <= 0 and
         versioncmp('2018.1.0', $facts['pe_server_version']) > 0)
       and $manage_fact_values_autovacuum_cost_delay ) {
    pe_databases::set_puppetdb_table_autovacuum_cost_delay_zero { 'fact_values' : }
  }

  if !empty($factsets_autovacuum_vacuum_scale_factor) {
    pe_databases::set_table_attribute { "Set autovacuum_vacuum_scale_factor=${factsets_autovacuum_vacuum_scale_factor} for factsets" :
      db                    => 'pe-puppetdb',
      table_name            => 'factsets',
      table_attribute       => 'autovacuum_vacuum_scale_factor',
      table_attribute_value => sprintf('%#.2f', $factsets_autovacuum_vacuum_scale_factor),
    }
  }

  if !empty($reports_autovacuum_vacuum_scale_factor) {
    pe_databases::set_table_attribute { "Set autovacuum_vacuum_scale_factor=${reports_autovacuum_vacuum_scale_factor} for reports" :
      db                    => 'pe-puppetdb',
      table_name            => 'reports',
      table_attribute       => 'autovacuum_vacuum_scale_factor',
      table_attribute_value => sprintf('%#.2f', $reports_autovacuum_vacuum_scale_factor),
    }
  }

  if !empty($catalogs_autovacuum_vacuum_scale_factor) {
    pe_databases::set_table_attribute { "Set autovacuum_vacuum_scale_factor=${catalogs_autovacuum_vacuum_scale_factor} for catalogs" :
      db                    => 'pe-puppetdb',
      table_name            => 'catalogs',
      table_attribute       => 'autovacuum_vacuum_scale_factor',
      table_attribute_value => sprintf('%#.2f', $catalogs_autovacuum_vacuum_scale_factor),
    }
  }

  if !empty($certnames_autovacuum_vacuum_scale_factor) {
    pe_databases::set_table_attribute { "Set autovacuum_vacuum_scale_factor=${certnames_autovacuum_vacuum_scale_factor} for certnames" :
      db                    => 'pe-puppetdb',
      table_name            => 'certnames',
      table_attribute       => 'autovacuum_vacuum_scale_factor',
      table_attribute_value => sprintf('%#.2f', $certnames_autovacuum_vacuum_scale_factor),
    }
  }

  if !empty($fact_paths_autovacuum_vacuum_scale_factor) {
    pe_databases::set_table_attribute { "Set autovacuum_vacuum_scale_factor=${fact_paths_autovacuum_vacuum_scale_factor} for fact_paths" :
      db                    => 'pe-puppetdb',
      table_name            => 'fact_paths',
      table_attribute       => 'autovacuum_vacuum_scale_factor',
      table_attribute_value => sprintf('%#.2f', $fact_paths_autovacuum_vacuum_scale_factor),
    }
  }

  if $manage_reports_autovacuum_cost_delay {
    pe_databases::set_puppetdb_table_autovacuum_cost_delay_zero { 'reports' : }
  }
}
