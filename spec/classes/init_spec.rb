require 'spec_helper'

describe 'pe_databases' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }
    end
  end

  context 'with default parameters' do
    it {
      is_expected.to contain_class('pe_databases::pg_repack').with(disable_maintenance: false)

      is_expected.to contain_file('/opt/puppetlabs/pe_databases').with(
        ensure: 'directory',
        mode: '0755',
      )
      is_expected.to contain_file('/opt/puppetlabs/pe_databases/scripts').with(
        ensure: 'directory',
        mode: '0755',
      )

      is_expected.to contain_exec('pe_databases_daemon_reload').with(
        command: 'systemctl daemon-reload',
        path: ['/bin', '/usr/bin'],
        refreshonly: true,
      )
    }
  end

  context 'when systemd is not the init provider' do
    let(:facts) { { pe_databases: { have_systemd: false } } }

    it { is_expected.to contain_notify('pe_databases_systemd_warn') }
  end
end
