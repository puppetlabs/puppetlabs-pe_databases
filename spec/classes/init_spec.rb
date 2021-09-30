require 'spec_helper'

describe 'pe_databases' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }
    end
  end

  context 'on latest PE release' do
    it { is_expected.to contain_class('pe_databases::pg_repack') }
  end

  context 'on unsupported PE release' do
    let(:facts) { { pe_server_version: '2019.0.1' } }

    it { is_expected.to contain_notify('pe_databases_version_warn') }
  end

  context 'when systemd is not the init provider' do
    let(:facts) { { pe_databases: { have_systemd: false } } }

    it { is_expected.to contain_notify('pe_databases_systemd_warn') }
  end

  context 'backups are not included by default' do
    it { is_expected.not_to contain_class('pe_databases::backup') }
  end

  context 'backups are included if configured' do
    let(:params) { { manage_database_backups: true } }

    it { is_expected.to contain_class('pe_databases::backup') }
  end
end
