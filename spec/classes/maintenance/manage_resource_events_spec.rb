require 'spec_helper'

describe 'pe_databases::maintenance::manage_resource_events' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:pre_condition) { "class { 'pe_databases': }" }
      let(:facts) { os_facts }

      it { is_expected.to compile }
    end

    let(:pre_condition) do
      <<-MANIFEST
        file { '/opt/puppetlabs/pe_databases/scripts':  ensure => 'directory' }
        file { '/var/log/puppetlabs/pe_databases_cron': ensure => 'directory' }
      MANIFEST
    end

    context 'with resource_events_ttl => 0' do
      let(:params) do
        {
          'disable_maintenance' => false,
          'resource_events_ttl' => 0,
          'script_directory'    => '/opt/puppetlabs/pe_databases/scripts',
          'logging_directory'   => '/var/log/puppetlabs/pe_databases_cron',
        }
      end

      it { is_expected.to contain_cron('DELETE FROM resource_events').with_ensure('absent') }
    end
    context 'with resource_events_ttl => 3' do
      let(:params) do
        {
          'disable_maintenance' => true,
          'resource_events_ttl' => 3,
          'script_directory'    => '/opt/puppetlabs/pe_databases/scripts',
          'logging_directory'   => '/var/log/puppetlabs/pe_databases_cron',
        }
      end

      it { is_expected.to contain_cron('DELETE FROM resource_events').with_ensure('absent') }
    end
    context 'with resource_events_ttl => 3' do
      let(:params) do
        {
          'disable_maintenance' => false,
          'resource_events_ttl' => 3,
          'script_directory'    => '/opt/puppetlabs/pe_databases/scripts',
          'logging_directory'   => '/var/log/puppetlabs/pe_databases_cron',
        }
      end

      it { is_expected.to contain_cron('DELETE FROM resource_events').with_ensure('present') }
    end
  end
end
