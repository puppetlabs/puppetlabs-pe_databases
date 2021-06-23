require 'spec_helper_acceptance'

describe 'reset_pgrepack_schema task' do
  before(:all) do
    pp = <<-MANIFEST
        include pe_databases
        MANIFEST

    # Run it twice and test for idempotency
    idempotent_apply(pp)
  end
  it 'returns success' do
    result = run_bolt_task('pe_databases::reset_pgrepack_schema')
    expect(result.stdout).to contain(%r{success})
  end
end
