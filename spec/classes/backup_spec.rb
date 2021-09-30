require 'spec_helper'

describe 'pe_databases::backup' do
  context 'when backing up tables' do
    let (:pre_condition) {'include pe_databases'}
    it {
      # I have no idea how this works, but these are the resources we should end up with
      is_expected.to contain_cron('puppet_enterprise_database_backup_[pe-activity, pe-classifier, pe-inventory, pe-orchestrator, pe-postgres, pe-rbac]')
      is_expected.to contain_cron('puppet_enterprise_database_backup_[pe-puppetdb]')
    }
  end
end
