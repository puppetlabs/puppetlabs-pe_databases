require 'spec_helper'

describe 'pe_databases::collect' do
  context 'when repacking tables' do
    let(:pre_condition) do
      <<-PRE_COND
      define puppet_enterprise::deprecated_parameter() {}
      include pe_databases
      PRE_COND
    end
    let(:title) { 'test' }
    let(:params) do
      {
        command: 'foo',
        on_cal: 'bar',
        tables: ['baz'],
      }
    end

    it {
      is_expected.to contain_service('pe_databases-test.timer').with_ensure('running')
      is_expected.to contain_service('pe_databases-test.service')

      is_expected.to contain_file('/etc/systemd/system/pe_databases-test.timer').with_content(%r{bar})
      is_expected.to contain_file('/etc/systemd/system/pe_databases-test.service').with_content(
        %r{ExecStart=foo.*-t baz},
      )

      is_expected.to contain_service('pe_databases-test.service').that_notifies(
        'Exec[pe_databases_daemon_reload]',
      )
      is_expected.to contain_service('pe_databases-test.timer').that_subscribes_to(
        'File[/etc/systemd/system/pe_databases-test.timer]',
      )
    }
  end

  context 'when disabling maintenance' do
    let(:pre_condition) do
      <<-PRE_COND
      define puppet_enterprise::deprecated_parameter() {}
      include pe_databases
      PRE_COND
    end
    let(:title) { 'test' }
    let(:params) do
      {
        disable_maintenance: true,
        command: 'foo',
        on_cal: 'bar',
        tables: ['baz'],
      }
    end

    it {
      is_expected.to contain_file('/etc/systemd/system/pe_databases-test.timer').with_ensure('absent')
      is_expected.to contain_file('/etc/systemd/system/pe_databases-test.service').with_ensure('absent')
      is_expected.to contain_service('pe_databases-test.timer').with_ensure('stopped')
    }
  end
end
