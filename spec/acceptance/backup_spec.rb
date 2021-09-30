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
end
