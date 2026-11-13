# frozen_string_literal: true

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

  it 'returns success for the pe-activity database' do
    result = run_bolt_task('pe_databases::reset_pgrepack_schema', 'database' => 'pe-activity')
    expect(result.stdout).to contain(%r{success})
  end

  it 'fails for an invalid database name' do
    # Bolt checks the parameter against the task metadata before running the task
    ['bad;name', '-h', '-x', 'pe-orchestrator'].each do |name|
      expect { run_bolt_task('pe_databases::reset_pgrepack_schema', { 'database' => name }) }
        .to raise_error(%r{expects an undef value or a match for Enum})
    end
  end

  context 'with pe_databases-facts.service running' do
    psql = 'cd /tmp && sudo -u pe-postgres /opt/puppetlabs/server/bin/psql -d pe-puppetdb'

    before(:all) do
      # Hold a lock so the repack run stays active until the lock is released.
      # The whole command line runs in one detached shell, so the lock holder
      # keeps running after this step returns.
      lock_sql = 'BEGIN; LOCK TABLE public.fact_paths IN ACCESS EXCLUSIVE MODE; SELECT pg_sleep(45);'
      run_shell("setsid nohup sh -c '#{psql} -c \"#{lock_sql}\"' >/dev/null 2>&1 &")

      held_sql = "SELECT count(*) FROM pg_locks WHERE relation = 'public.fact_paths'::regclass AND mode = 'AccessExclusiveLock' AND granted"
      held = 0
      30.times do
        held = run_shell("#{psql} -At -c \"#{held_sql}\"", expect_failures: true).stdout.to_s.strip.to_i
        break if held >= 1

        sleep 1
      end
      raise 'lock on public.fact_paths was not held within 30 seconds' unless held >= 1

      run_shell('systemctl start --no-block pe_databases-facts.service')
      # Wait up to 30 seconds for the unit to report activating
      state = ''
      30.times do
        state = run_shell('systemctl show -p ActiveState pe_databases-facts.service', expect_failures: true).stdout.to_s
        break if state.include?('ActiveState=activating')

        sleep 1
      end
      raise "pe_databases-facts.service never reached activating, last state: #{state.strip}" unless state.include?('ActiveState=activating')
    end

    after(:all) do
      run_shell("#{psql} -c \"SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE query LIKE '%pg_sleep(45)%' AND pid <> pg_backend_pid()\"", expect_failures: true)
      run_shell('systemctl stop pe_databases-facts.service', expect_failures: true)
    end

    # The task prints its error as JSON, which Bolt returns as the result value
    let(:output) { run_bolt_task('pe_databases::reset_pgrepack_schema', {}, expect_failures: true).result['message'].to_s }

    it { expect(output).to match(%r{pe_databases-facts\.service}) }
    it { expect(output).to match(%r{is running}) }

    # The examples run in order: the second one stops the unit and releases
    # the lock that the first one relies on.
    it 'runs again once the unit is stopped and the lock is released' do
      run_shell("#{psql} -c \"SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE query LIKE '%pg_sleep(45)%' AND pid <> pg_backend_pid()\"", expect_failures: true)
      run_shell('systemctl stop pe_databases-facts.service', expect_failures: true)
      result = run_bolt_task('pe_databases::reset_pgrepack_schema')
      expect(result.stdout).to contain(%r{success})
    end
  end
end
