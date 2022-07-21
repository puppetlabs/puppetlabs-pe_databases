require 'spec_helper'

describe 'pe_databases::pg_repack' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:pre_condition) do
        "class { 'pe_databases':
          manage_postgresql_settings =>  false,
          manage_table_settings      =>  false,
        }"
      end
      let(:facts) { os_facts }

      it { is_expected.to compile }
      context 'on < PE 2019.3.0' do
        before :each do
          facts['pe_server_version'] = '2019.1.0'
          facts['pe_postgresql_info']['installed_server_version'] = 9.6
        end
        it {
          # TODO: postgres versions
          is_expected.to contain_service('pe_databases-resource_events.timer').with_ensure('running')
          is_expected.to contain_service('pe_databases-reports.timer').with_ensure('running')
        }
      end

      context 'on < PE 2019.3.0 with postgresql 11' do
        before :each do
          facts['pe_server_version'] = '2019.2.0'
          facts['pe_postgresql_info']['installed_server_version'] = 11
        end
        it {
          # TODO: postgres versions
          is_expected.to contain_service('pe_databases-resource_events.timer').with_ensure('running')
          is_expected.to contain_service('pe_databases-reports.timer').with_ensure('running')
        }
      end

      context 'on < PE 2019.7.0' do
        before :each do
          facts['pe_server_version'] = '2019.5.0'
          facts['pe_postgresql_info']['installed_server_version'] = 11
        end
        it {
          # TODO: postgres versions
          is_expected.to contain_service('pe_databases-reports.timer').with_ensure('running')
          is_expected.not_to contain_service('pe_databases-resource_events.timer').with_ensure('running')
        }
      end

      context 'on >= PE 2019.7.0' do
        before :each do
          facts['pe_server_version'] = '2019.7.0'
          facts['pe_postgresql_info']['installed_server_version'] = 11
        end
        it {
          is_expected.not_to contain_service('pe_databases-reports.timer').with_ensure('running')
          is_expected.not_to contain_service('pe_databases-resource_events.timer').with_ensure('running')
        }
      end

      context 'on >= PE 2019.8.2' do
        before :each do
          facts['pe_server_version'] = '2019.8.2'
          facts['pe_postgresql_info']['installed_server_version'] = 11
        end
        it {
          is_expected.to contain_service('pe_databases-catalogs.timer').with_ensure('running')
        }
      end
    end
  end
end
