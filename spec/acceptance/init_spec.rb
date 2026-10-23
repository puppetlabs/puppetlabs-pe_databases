# frozen_string_literal: true

require 'spec_helper_acceptance'

describe 'pe_databases class' do
  context 'with module default parameters' do
    it 'applies the class idempotently' do
      pp = <<-MANIFEST
        include pe_databases
      MANIFEST

      # Run it twice and test for idempotency
      expect { idempotent_apply(pp) }.not_to raise_error
    end
  end

  describe 'check pe_databases script directory' do
    it 'scripts folder exists' do
      expect(file('/opt/puppetlabs/pe_databases/scripts')).to be_directory
    end
  end

  describe 'check systemd fact' do
    it 'is true on all supported OS' do
      expect(host_inventory['facter']['pe_databases']['have_systemd']).to be true
    end
  end
end
