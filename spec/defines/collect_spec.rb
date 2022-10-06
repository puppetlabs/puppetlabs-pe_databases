require 'spec_helper'

describe 'pe_databases::collect' do
  context 'when repacking tables' do
    let(:pre_condition) { 'include pe_databases' }
    let(:title) { 'test' }
    let(:params) do
      {
        command: 'foo',
        on_cal: 'bar',
      }
    end

    it {
      is_expected.to contain_service('pe_databases-test.timer').with_ensure('running')
      is_expected.to contain_service('pe_databases-test.service')

      is_expected.to contain_file('/etc/systemd/system/pe_databases-test.timer').with_content(%r{bar})
      is_expected.to contain_file('/etc/systemd/system/pe_databases-test.service').with_content(
        %r{ExecStart=foo},
      )
    }
  end

  context 'when disabling maintenance' do
    let(:pre_condition) { 'include pe_databases' }
    let(:title) { 'test' }
    let(:params) do
      {
        disable_maintenance: true,
        command: 'foo',
        on_cal: 'bar',
      }
    end

    it {
      is_expected.to contain_service('pe_databases-test.timer').with_ensure('stopped')
    }
  end
end
