require 'spec_helper'

describe 'pe_databases' do
  let(:params) do
    {
      manage_database_backups:  false,
      manage_postgresql_settings: false,
      manage_table_settings:  false,
    }
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }
    end
  end
end
