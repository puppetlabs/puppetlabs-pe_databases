require 'spec_helper_acceptance'

describe 'pe_databases with manage database backups' do
  it 'applies the class with default parameters' do
    pp = <<-MANIFEST
       class { 'pe_databases':
         manage_database_backups => true
       }#{' '}
       MANIFEST

    # Run it twice and test for idempotency
    idempotent_apply(pp)
  end
  it 'checks if backup cron jobs are up' do
    run_shell('crontab -l -u pe-postgres') do |r|
      expect(r.stdout).to match(%r{pe-activity, pe-classifier, pe-inventory, pe-orchestrator, pe-postgres, pe-rbac})
      expect(r.stdout).to match(%r{pe-puppetdb})
    end
  end
end
