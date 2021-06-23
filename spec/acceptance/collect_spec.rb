require 'spec_helper_acceptance'

describe 'check collect with default values' do
  before(:all) do
    pp = <<-MANIFEST
        include pe_databases
        MANIFEST
    idempotent_apply(pp)
  end
  context 'check if service files are created' do
    it 'service files are created' do
      files = run_shell('ls /etc/systemd/system/pe_databases-*.service').stdout
      expect(files.split("\n").count).to be >= 3
    end
    it 'service timer files are created' do
      files = run_shell('ls /etc/systemd/system/pe_databases-*.timer').stdout
      expect(files.split("\n").count).to be >= 3
    end
  end
end
