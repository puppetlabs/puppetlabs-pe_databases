require 'spec_helper'

describe 'pe_databases::maintenance::vacuum_full' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:pre_condition) { "class { 'pe_databases': manage_database_backups =>  false, manage_postgresql_settings => false, manage_table_settings =>  false,}" }
      let(:facts) { os_facts }

      it { is_expected.to compile }
    end
  end
end
