require 'spec_helper'

describe 'pe_databases::maintenance' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:pre_condition) { "class { 'pe_databases': manage_database_backups =>  false, manage_postgresql_settings => false, manage_table_settings =>  false,}" }
      let(:facts) { os_facts }

      it { is_expected.to compile }

      context 'on PE 2019.0.0' do
        before(:each) do
          facts['pe_server_version'] = '2019.0.0'
        end

        it { is_expected.to contain_class('pe_databases::maintenance::vacuum_full') }
        it { is_expected.not_to contain_class('pe_databases::maintenance::pg_repack') }
      end
      context 'on PE 2018.1.4' do
        before(:each) do
          facts['pe_server_version'] = '2018.1.4'
        end

        it { is_expected.to contain_class('pe_databases::maintenance::vacuum_full') }
        it { is_expected.not_to contain_class('pe_databases::maintenance::pg_repack') }
      end
      context 'on PE 2018.1.8' do
        before(:each) do
          facts['pe_server_version'] = '2018.1.9'
        end

        it { is_expected.to contain_class('pe_databases::maintenance::vacuum_full').with('disable_maintenance' => true) }
        it { is_expected.to contain_class('pe_databases::maintenance::pg_repack') }
      end
      context 'on PE 2019.0.3' do
        before(:each) do
          facts['pe_server_version'] = '2019.0.3'
        end

        it { is_expected.to contain_class('pe_databases::maintenance::vacuum_full').with('disable_maintenance' => true) }
        it { is_expected.to contain_class('pe_databases::maintenance::pg_repack') }
      end
    end
  end
end
