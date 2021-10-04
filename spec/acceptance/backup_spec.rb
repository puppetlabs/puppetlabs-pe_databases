require 'spec_helper_acceptance'

describe 'pe_databases with manage database backups' do
  it 'applies the class with default parameters' do
    pp = <<-MANIFEST
       class { 'pe_databases':
         manage_database_backups => true
       }#{' '}
       MANIFEST

    # Expect a change due to backup notify
    apply_manifest(pp)
    apply_manifest(pp, expect_changes: true)
  end
end
