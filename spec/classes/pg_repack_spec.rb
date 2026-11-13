# frozen_string_literal: true

require 'spec_helper'

REPACK_CMD = '/opt/puppetlabs/server/apps/postgresql/11/bin/pg_repack --jobs 1'
JOBS = ['facts', 'catalogs', 'other', 'activity'].freeze
TABLES = {
  'facts' => {
    tables: '-t fact_paths',
    schedule: 'Tue,Sat \*-\*-\* 04:30:00',
    database: '-d pe-puppetdb',
  },
  'catalogs' => {
    tables: '-t catalogs -t catalog_resources -t catalog_inputs -t edges -t certnames',
    schedule: 'Sun,Thu \*-\*-\* 04:30:00',
    database: '-d pe-puppetdb',
  },
  'other' => {
    tables: '-t producers -t resource_params -t resource_params_cache',
    schedule: '\*-\*-20 05:30:00',
    database: '-d pe-puppetdb',
  },
  'activity' => {
    tables: '-t events -t event_commits',
    schedule: 'Wed,Fri \*-\*-\* 04:30:00',
    database: '-d pe-activity',
  },
}.freeze
DATABASES = { 'facts' => 'pe-puppetdb', 'catalogs' => 'pe-puppetdb', 'other' => 'pe-puppetdb', 'activity' => 'pe-activity' }.freeze
DEPRECATED_PARAMS = [
  'pe_databases::pg_repack::reports_tables_repack_timer',
  'pe_databases::pg_repack::resource_events_tables_repack_timer',
].freeze
OLD_CRONS = [
  'pg_repack facts tables', 'pg_repack catalogs tables', 'pg_repack other tables',
  'pg_repack reports tables', 'pg_repack resource_events tables',
  'VACUUM FULL facts tables',
  'VACUUM FULL catalogs tables',
  'VACUUM FULL other tables',
  'Maintain PE databases'
].freeze
SERVICE_DIR = '/etc/systemd/system'
SCRIPT = '/opt/puppetlabs/pe_databases/scripts/repack_cleanup.sh'
WRAPPER = '/opt/puppetlabs/pe_databases/scripts/repack_run.sh'
FACTS_SIBLINGS_ARG = '--siblings pe_databases-catalogs\.service,pe_databases-other\.service'
SIBLINGS = {
  'facts' => ['pe_databases-catalogs.service', 'pe_databases-other.service'],
  'catalogs' => ['pe_databases-facts.service', 'pe_databases-other.service'],
  'other' => ['pe_databases-facts.service', 'pe_databases-catalogs.service'],
  'activity' => [],
}.freeze
GOOD_TIMESPANS = ['12h', '30s', '1min', '10min', '1min 30s', '1h30m', '1.5h', '30', '2d', '1w', '0'].freeze
BAD_TIMESPANS = ['', ' ', '12x', '5.5.5', '1..x', 'foo', 'bad;x', '%h', '-1', 'infinity', '1M', "12h\nExecStart=/bin/x", "12h\n30s", ' 12h', "\t12h"].freeze
MAINTENANCE_PRE_COND = <<~PRE_COND
  define puppet_enterprise::deprecated_parameter() {}

  class { 'pe_databases': manage_database_maintenance => false }
PRE_COND

describe 'pe_databases::pg_repack' do
  let(:facts) { { processors: { count: 4 } } }
  let(:pre_condition) do
    <<~PRE_COND
      define puppet_enterprise::deprecated_parameter() {}

      include pe_databases
    PRE_COND
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }
    end
  end

  context 'with default parameters' do
    TABLES.each do |name, val|
      context "with the #{name} timer" do
        it do
          expect(catalogue).to contain_pe_databases__collect(name).with(
            disable_maintenance: false,
            command: "#{REPACK_CMD} --elevel DEBUG --echo #{val[:database]}",
            # Strip the backslash character because this is not a regex
            on_cal: val[:schedule].to_s.tr('\\', ''),
          )
        end

        it { expect(catalogue).to contain_service("pe_databases-#{name}.timer").with_ensure('running') }
        it { expect(catalogue).to contain_service("pe_databases-#{name}.service") }
        it { expect(catalogue).to contain_file("#{SERVICE_DIR}/pe_databases-#{name}.timer").with_content(%r{OnCalendar=#{val[:schedule]}}) }

        it do
          expect(catalogue).to contain_file("#{SERVICE_DIR}/pe_databases-#{name}.service").with_content(
            %r{^ExecStart=\S+/repack_run\.sh \S+/repack_cleanup\.sh .* -- #{REPACK_CMD} --elevel DEBUG --echo #{val[:database]} #{val[:tables]}$},
          )
        end
      end
    end

    it { expect(catalogue).to contain_file("#{SERVICE_DIR}/pe_databases-facts.service").without_content(%r{factsets}) }

    DEPRECATED_PARAMS.each do |deprecated_param|
      it { expect(catalogue).to contain_puppet_enterprise__deprecated_parameter(deprecated_param) }
    end

    OLD_CRONS.each do |cron|
      it { expect(catalogue).to contain_cron(cron).with(ensure: 'absent') }
    end
  end

  context 'when customizing timers' do
    let(:pre_condition) do
      <<~PRE_COND
        define puppet_enterprise::deprecated_parameter() {}

        class {'pe_databases': facts_tables_repack_timer => 'Tue *-*-* 04:20:00'}
      PRE_COND
    end

    it { expect(catalogue).to contain_pe_databases__collect('facts').with(on_cal: 'Tue *-*-* 04:20:00') }
  end

  context 'with per-job repack flags' do
    let(:pre_condition) { MAINTENANCE_PRE_COND }

    context 'with facts_tables_repack_enabled => false' do
      let(:params) { { facts_tables_repack_enabled: false } }

      it { expect(catalogue).to contain_pe_databases__collect('facts').with_disable_maintenance(true) }
      it { expect(catalogue).to contain_file("#{SERVICE_DIR}/pe_databases-facts.timer").with_ensure('absent') }
      it { expect(catalogue).to contain_service('pe_databases-facts.timer').with(ensure: 'stopped', enable: false) }

      ['catalogs', 'other', 'activity'].each do |name|
        it { expect(catalogue).to contain_pe_databases__collect(name).with_disable_maintenance(false) }
        it { expect(catalogue).to contain_service("pe_databases-#{name}.timer").with_ensure('running') }
      end
    end

    JOBS.each do |disabled|
      context "with only #{disabled}_tables_repack_enabled => false" do
        let(:params) { { "#{disabled}_tables_repack_enabled": false } }

        JOBS.each do |name|
          it { expect(catalogue).to contain_pe_databases__collect(name).with_disable_maintenance(name == disabled) }
        end
      end
    end

    context 'with disable_maintenance => true and all flags true' do
      let(:params) do
        {
          disable_maintenance: true,
          facts_tables_repack_enabled: true,
          catalogs_tables_repack_enabled: true,
          other_tables_repack_enabled: true,
          activity_tables_repack_enabled: true,
        }
      end

      JOBS.each do |name|
        it { expect(catalogue).to contain_pe_databases__collect(name).with_disable_maintenance(true) }
      end
    end
  end

  context 'with kill_backend and wait_timeout' do
    let(:pre_condition) { MAINTENANCE_PRE_COND }

    {
      'kill_backend => false' => [{ kill_backend: false }, '--no-kill-backend'],
      'wait_timeout => 30' => [{ wait_timeout: 30 }, '-T 30'],
      'kill_backend => false and wait_timeout => 30' => [{ kill_backend: false, wait_timeout: 30 }, '--no-kill-backend -T 30'],
    }.each do |description, (parameters, flags)|
      context "with #{description}" do
        let(:params) { parameters }

        DATABASES.each do |name, db|
          it { expect(catalogue).to contain_pe_databases__collect(name).with_command("#{REPACK_CMD} --elevel DEBUG --echo #{flags} -d #{db}") }
        end
      end
    end

    context 'with wait_timeout => 0' do
      let(:params) { { wait_timeout: 0 } }

      it { is_expected.to compile.and_raise_error(%r{Integer\[1\]}) }
    end
  end

  context 'when customizing log parameters' do
    # Load the rspec hieradata.  This data sets repack_log_level: 'INFO' and enable_echo: false
    let(:hiera_config) { 'hiera-rspec.yaml' }

    # The command should have --elevel INFO and not contain --echo according to the hieradata
    it do
      expect(catalogue).to contain_pe_databases__collect('facts').with(
        command: "#{REPACK_CMD} --elevel INFO #{TABLES['facts'][:database]}",
      )
    end

    # The service file should have --elevel INFO and not contain --echo according to the hieradata
    it do
      expect(catalogue).to contain_file("#{SERVICE_DIR}/pe_databases-facts.service").with_content(
        %r{ -- #{REPACK_CMD} --elevel INFO #{TABLES['facts'][:database]} #{TABLES['facts'][:tables]}$},
      )
    end
  end

  context 'with runtime limit, cleanup script and siblings' do
    let(:pre_condition) { MAINTENANCE_PRE_COND }

    it { expect(catalogue).to contain_file(SCRIPT).with(ensure: 'file', mode: '0755', owner: 'root', group: 'root', source: 'puppet:///modules/pe_databases/repack_cleanup.sh') }
    it { expect(catalogue).to contain_file(WRAPPER).with(ensure: 'file', mode: '0755', owner: 'root', group: 'root', source: 'puppet:///modules/pe_databases/repack_run.sh') }

    JOBS.each do |name|
      it { expect(catalogue).to contain_file(SCRIPT).that_comes_before("Pe_databases::Collect[#{name}]") }
      it { expect(catalogue).to contain_file(WRAPPER).that_comes_before("Pe_databases::Collect[#{name}]") }
      it { expect(catalogue).to contain_file("#{SERVICE_DIR}/pe_databases-#{name}.service").with_content(%r{^TimeoutStartSec=12h$}) }
      it { expect(catalogue).to contain_pe_databases__collect(name).with_stop_timeout('10min') }
      it { expect(catalogue).to contain_file("#{SERVICE_DIR}/pe_databases-#{name}.service").with_content(%r{^TimeoutStopSec=10min$}) }
      it { expect(catalogue).to contain_file("#{SERVICE_DIR}/pe_databases-#{name}.service").with_content(%r{^KillMode=mixed$}) }
      it { expect(catalogue).to contain_file("#{SERVICE_DIR}/pe_databases-#{name}.service").with_content(%r{^KillSignal=SIGTERM$}) }
      it { expect(catalogue).to contain_file("#{SERVICE_DIR}/pe_databases-#{name}.service").without_content(%r{SIGINT}) }
    end

    SIBLINGS.each do |name, units|
      it { expect(catalogue).to contain_pe_databases__collect(name).with_sibling_units(units) }
    end

    it do
      expect(catalogue).to contain_file("#{SERVICE_DIR}/pe_databases-facts.service").with_content(
        %r{^ExecStartPre=-#{SCRIPT} #{FACTS_SIBLINGS_ARG} pe-puppetdb fact_paths$}o,
      )
    end

    it do
      expect(catalogue).to contain_file("#{SERVICE_DIR}/pe_databases-facts.service").with_content(
        %r{^ExecStart=#{WRAPPER} #{SCRIPT} #{FACTS_SIBLINGS_ARG} pe-puppetdb fact_paths -- #{REPACK_CMD} --elevel DEBUG --echo -d pe-puppetdb -t fact_paths$}o,
      )
    end

    DATABASES.each do |name, db|
      it { expect(catalogue).to contain_pe_databases__collect(name).with_database(db) }
    end

    it do
      expect(catalogue).to contain_file("#{SERVICE_DIR}/pe_databases-activity.service").with_content(
        %r{^ExecStartPre=-#{SCRIPT} pe-activity events event_commits$}o,
      )
    end

    it do
      expect(catalogue).to contain_file("#{SERVICE_DIR}/pe_databases-activity.service").with_content(
        %r{^ExecStart=#{WRAPPER} #{SCRIPT} pe-activity events event_commits -- #{REPACK_CMD} --elevel DEBUG --echo -d pe-activity -t events -t event_commits$}o,
      )
    end

    context 'with stop_timeout => 20min' do
      let(:params) { { stop_timeout: '20min' } }

      JOBS.each do |name|
        it { expect(catalogue).to contain_pe_databases__collect(name).with_stop_timeout('20min') }
        it { expect(catalogue).to contain_file("#{SERVICE_DIR}/pe_databases-#{name}.service").with_content(%r{^TimeoutStopSec=20min$}) }
      end
    end

    context 'with max_runtime => 6h' do
      let(:params) { { max_runtime: '6h' } }

      JOBS.each do |name|
        it { expect(catalogue).to contain_file("#{SERVICE_DIR}/pe_databases-#{name}.service").with_content(%r{^TimeoutStartSec=6h$}) }
      end
    end

    context 'with catalogs_tables_repack_enabled => false' do
      let(:params) { { catalogs_tables_repack_enabled: false } }

      it 'does not change the sibling list of the other jobs when a sibling is disabled' do
        expect(catalogue).to contain_pe_databases__collect('facts').with_sibling_units(SIBLINGS['facts'])
      end
    end

    context 'with facts_tables_repack_enabled => false' do
      let(:params) { { facts_tables_repack_enabled: false } }

      it { expect(catalogue).to contain_file("#{SERVICE_DIR}/pe_databases-facts.service").with_ensure('absent') }

      ['catalogs', 'other', 'activity'].each do |name|
        it { expect(catalogue).to contain_file("#{SERVICE_DIR}/pe_databases-#{name}.service").with_ensure('present') }
      end
    end
  end

  context 'with validated parameters' do
    let(:pre_condition) { MAINTENANCE_PRE_COND }

    ['max_runtime', 'stop_timeout'].each do |param|
      GOOD_TIMESPANS.each do |value|
        context "with #{param} => #{value.inspect}" do
          let(:params) { { param.to_sym => value } }

          it { is_expected.to compile }
        end
      end

      BAD_TIMESPANS.each do |value|
        context "with #{param} => #{value.inspect}" do
          let(:params) { { param.to_sym => value } }

          it { is_expected.to compile.and_raise_error(%r{Pe_databases::Timespan}) }
        end
      end
    end
  end
end
