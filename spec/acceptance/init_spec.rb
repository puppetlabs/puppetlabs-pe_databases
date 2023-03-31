require 'spec_helper_acceptance'

describe 'pe_databases class' do
  context 'activates module default parameters' do
    it 'applies the class with default parameters' do
      pp = <<-MANIFEST
        include pe_databases
        MANIFEST

      # Run it twice and test for idempotency
      idempotent_apply(pp)
    end
  end

  describe 'check pe_databases script directory' do
    it 'scripts folder exists' do
      expect(file('/opt/puppetlabs/pe_databases/scripts')).to be_directory
    end
  end

  describe 'check systemd fact' do
    run_shell('/opt/puppetlabs/bin/puppet plugin download')
    it 'is true on all supported OS' do
      expect(host_inventory['facter']['pe_databases']['have_systemd']).to eq true
    end
  end
end
