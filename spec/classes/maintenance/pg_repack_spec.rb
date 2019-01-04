require 'spec_helper'

describe 'pe_databases::maintenance::pg_repack' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:pre_condition) { "class { 'pe_databases': }" }
      let(:facts) { os_facts }

      it { is_expected.to compile }
    end
  end
end
