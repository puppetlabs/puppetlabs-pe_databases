require 'spec_helper'

describe 'pe_databases::pg_repack' do
  let(:facts) { { processors: { count: 4 } } }
  let(:repack_cmd) { '/opt/puppetlabs/server/apps/postgresql/11/bin/pg_repack --jobs 1' }
  let(:tables_hash) do
    {
      facts: {
        tables: '-t fact_paths',
        schedule: 'Tue,Sat \*-\*-\* 04:30:00',
        database: '-d pe-puppetdb',
      },
      catalogs: {
        tables: '-t catalogs -t catalog_resources -t catalog_inputs -t edges -t certnames',
        schedule: 'Sun,Thu \*-\*-\* 04:30:00',
        database: '-d pe-puppetdb',
      },
      other: {
        tables: '-t producers -t resource_params -t resource_params_cache',
        schedule: '\*-\*-20 05:30:00',
        database: '-d pe-puppetdb',
      },
      activity: {
        tables: '-t events -t event_commits',
        schedule: 'Wed,Fri \*-\*-\* 04:30:00',
        database: '-d pe-activity',
      }
    }
  end
  let(:pre_condition) do
    <<-PRE_COND
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
    it {
      tables_hash.each do |name, val|
        is_expected.to contain_pe_databases__collect(name).with(
          disable_maintenance: false,
          command: "#{repack_cmd} --elevel DEBUG --echo #{val[:database]}",
          # Strip the backslash character because this is not a regex
          on_cal: (val[:schedule]).to_s.tr('\\', ''),
        )

        is_expected.to contain_service("pe_databases-#{name}.timer").with_ensure('running')
        is_expected.to contain_service("pe_databases-#{name}.service")
        is_expected.to contain_file('/etc/systemd/system/pe_databases-facts.service').without_content(%r{factsets})

        is_expected.to contain_file("/etc/systemd/system/pe_databases-#{name}.timer").with_content(%r{OnCalendar=#{val[:schedule]}})
        is_expected.to contain_file("/etc/systemd/system/pe_databases-#{name}.service").with_content(
          %r{^ExecStart=\S+/repack_run\.sh \S+/repack_cleanup\.sh .* -- #{repack_cmd} --elevel DEBUG --echo #{val[:database]} #{val[:tables]}$},
        )

        [
          'pe_databases::pg_repack::reports_tables_repack_timer',
          'pe_databases::pg_repack::resource_events_tables_repack_timer',
        ].each do |deprecated_param|
          is_expected.to contain_puppet_enterprise__deprecated_parameter(deprecated_param)
        end
      end

      ['pg_repack facts tables', 'pg_repack catalogs tables', 'pg_repack other tables',
       'pg_repack reports tables', 'pg_repack resource_events tables',
       'VACUUM FULL facts tables',
       'VACUUM FULL catalogs tables',
       'VACUUM FULL other tables',
       'Maintain PE databases'].each do |cron|
         is_expected.to contain_cron(cron).with(ensure: 'absent')
       end
    }
  end

  context 'when customizing timers' do
    let(:pre_condition) do
      <<-PRE_COND
        define puppet_enterprise::deprecated_parameter() {}

        class {'pe_databases': facts_tables_repack_timer => 'Tue *-*-* 04:20:00'}
        PRE_COND
    end

    it {
      is_expected.to contain_pe_databases__collect('facts').with(
        on_cal: 'Tue *-*-* 04:20:00',
      )
    }
  end

  context 'with per-job repack flags' do
    let(:pre_condition) do
      <<-PRE_COND
        define puppet_enterprise::deprecated_parameter() {}

        class { 'pe_databases': manage_database_maintenance => false }
        PRE_COND
    end
    let(:jobs) { ['facts', 'catalogs', 'other', 'activity'] }

    context 'with facts_tables_repack_enabled => false' do
      let(:params) { { facts_tables_repack_enabled: false } }

      it {
        is_expected.to contain_pe_databases__collect('facts').with_disable_maintenance(true)
        is_expected.to contain_file('/etc/systemd/system/pe_databases-facts.timer').with_ensure('absent')
        is_expected.to contain_service('pe_databases-facts.timer').with(ensure: 'stopped', enable: false)

        ['catalogs', 'other', 'activity'].each do |name|
          is_expected.to contain_pe_databases__collect(name).with_disable_maintenance(false)
          is_expected.to contain_service("pe_databases-#{name}.timer").with_ensure('running')
        end
      }
    end

    ['facts', 'catalogs', 'other', 'activity'].each do |disabled|
      context "with only #{disabled}_tables_repack_enabled => false" do
        let(:params) { { "#{disabled}_tables_repack_enabled": false } }

        it {
          jobs.each do |name|
            is_expected.to contain_pe_databases__collect(name).with_disable_maintenance(name == disabled)
          end
        }
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

      it {
        jobs.each do |name|
          is_expected.to contain_pe_databases__collect(name).with_disable_maintenance(true)
        end
      }
    end
  end

  context 'with kill_backend and wait_timeout' do
    let(:pre_condition) do
      <<-PRE_COND
        define puppet_enterprise::deprecated_parameter() {}

        class { 'pe_databases': manage_database_maintenance => false }
        PRE_COND
    end
    let(:databases) { { 'facts' => 'pe-puppetdb', 'catalogs' => 'pe-puppetdb', 'other' => 'pe-puppetdb', 'activity' => 'pe-activity' } }

    context 'with kill_backend => false' do
      let(:params) { { kill_backend: false } }

      it {
        databases.each do |name, db|
          is_expected.to contain_pe_databases__collect(name).with_command("#{repack_cmd} --elevel DEBUG --echo --no-kill-backend -d #{db}")
        end
      }
    end

    context 'with wait_timeout => 30' do
      let(:params) { { wait_timeout: 30 } }

      it {
        databases.each do |name, db|
          is_expected.to contain_pe_databases__collect(name).with_command("#{repack_cmd} --elevel DEBUG --echo -T 30 -d #{db}")
        end
      }
    end

    context 'with kill_backend => false and wait_timeout => 30' do
      let(:params) { { kill_backend: false, wait_timeout: 30 } }

      it {
        databases.each do |name, db|
          is_expected.to contain_pe_databases__collect(name).with_command("#{repack_cmd} --elevel DEBUG --echo --no-kill-backend -T 30 -d #{db}")
        end
      }
    end

    context 'with wait_timeout => 0' do
      let(:params) { { wait_timeout: 0 } }

      it { is_expected.to compile.and_raise_error(%r{Integer\[1\]}) }
    end
  end

  context 'when customizing log parameters' do
    # Load the rspec hieradata.  This data sets repack_log_level: 'INFO' and enable_echo: false
    let(:hiera_config) { 'hiera-rspec.yaml' }

    it {
      # The command should have --elevel INFO and not contain --echo according to the hieradata
      is_expected.to contain_pe_databases__collect('facts').with(
        command: "#{repack_cmd} --elevel INFO #{tables_hash[:facts][:database]}",
      )

      # The service file should have --elevel INFO and not contain --echo according to the hieradata
      is_expected.to contain_file('/etc/systemd/system/pe_databases-facts.service').with_content(
        %r{ -- #{repack_cmd} --elevel INFO #{tables_hash[:facts][:database]} #{tables_hash[:facts][:tables]}$},
      )
    }
  end

  context 'with runtime limit, cleanup script and siblings' do
    let(:pre_condition) do
      <<-PRE_COND
        define puppet_enterprise::deprecated_parameter() {}

        class { 'pe_databases': manage_database_maintenance => false }
        PRE_COND
    end
    let(:script) { '/opt/puppetlabs/pe_databases/scripts/repack_cleanup.sh' }
    let(:wrapper) { '/opt/puppetlabs/pe_databases/scripts/repack_run.sh' }
    let(:facts_siblings_arg) { '--siblings pe_databases-catalogs\.service,pe_databases-other\.service' }
    let(:service_dir) { '/etc/systemd/system' }
    let(:jobs) { ['facts', 'catalogs', 'other', 'activity'] }
    let(:siblings) do
      {
        'facts' => ['pe_databases-catalogs.service', 'pe_databases-other.service'],
        'catalogs' => ['pe_databases-facts.service', 'pe_databases-other.service'],
        'other' => ['pe_databases-facts.service', 'pe_databases-catalogs.service'],
        'activity' => [],
      }
    end

    it {
      is_expected.to contain_file(script).with(
        ensure: 'file',
        mode: '0755',
        owner: 'root',
        group: 'root',
        source: 'puppet:///modules/pe_databases/repack_cleanup.sh',
      )
      is_expected.to contain_file(wrapper).with(
        ensure: 'file',
        mode: '0755',
        owner: 'root',
        group: 'root',
        source: 'puppet:///modules/pe_databases/repack_run.sh',
      )
      jobs.each do |name|
        is_expected.to contain_file(script).that_comes_before("Pe_databases::Collect[#{name}]")
        is_expected.to contain_file(wrapper).that_comes_before("Pe_databases::Collect[#{name}]")
        is_expected.to contain_file("#{service_dir}/pe_databases-#{name}.service").with_content(%r{^TimeoutStartSec=12h$})
      end
    }

    it {
      siblings.each do |name, units|
        is_expected.to contain_pe_databases__collect(name).with_sibling_units(units)
      end
      is_expected.to contain_file("#{service_dir}/pe_databases-facts.service").with_content(
        %r{^ExecStartPre=-#{script} #{facts_siblings_arg} pe-puppetdb fact_paths$},
      )
      is_expected.to contain_file("#{service_dir}/pe_databases-facts.service").with_content(
        %r{^ExecStart=#{wrapper} #{script} #{facts_siblings_arg} pe-puppetdb fact_paths -- #{repack_cmd} --elevel DEBUG --echo -d pe-puppetdb -t fact_paths$},
      )
    }

    it {
      is_expected.to contain_pe_databases__collect('activity').with_database('pe-activity')
      ['facts', 'catalogs', 'other'].each do |name|
        is_expected.to contain_pe_databases__collect(name).with_database('pe-puppetdb')
      end
      is_expected.to contain_file("#{service_dir}/pe_databases-activity.service").with_content(
        %r{^ExecStartPre=-#{script} pe-activity events event_commits$},
      )
      is_expected.to contain_file("#{service_dir}/pe_databases-activity.service").with_content(
        %r{^ExecStart=#{wrapper} #{script} pe-activity events event_commits -- #{repack_cmd} --elevel DEBUG --echo -d pe-activity -t events -t event_commits$},
      )
    }

    it {
      jobs.each do |name|
        is_expected.to contain_pe_databases__collect(name).with_stop_timeout('10min')
        is_expected.to contain_file("#{service_dir}/pe_databases-#{name}.service").with_content(%r{^TimeoutStopSec=10min$})
        is_expected.to contain_file("#{service_dir}/pe_databases-#{name}.service").with_content(%r{^KillMode=mixed$})
        is_expected.to contain_file("#{service_dir}/pe_databases-#{name}.service").with_content(%r{^KillSignal=SIGTERM$})
        is_expected.to contain_file("#{service_dir}/pe_databases-#{name}.service").without_content(%r{SIGINT})
      end
    }

    context 'with stop_timeout => 20min' do
      let(:params) { { stop_timeout: '20min' } }

      it {
        jobs.each do |name|
          is_expected.to contain_pe_databases__collect(name).with_stop_timeout('20min')
          is_expected.to contain_file("#{service_dir}/pe_databases-#{name}.service").with_content(%r{^TimeoutStopSec=20min$})
        end
      }
    end

    context 'with max_runtime => 6h' do
      let(:params) { { max_runtime: '6h' } }

      it {
        jobs.each do |name|
          is_expected.to contain_file("#{service_dir}/pe_databases-#{name}.service").with_content(%r{^TimeoutStartSec=6h$})
        end
      }
    end

    context 'with catalogs_tables_repack_enabled => false' do
      let(:params) { { catalogs_tables_repack_enabled: false } }

      it 'does not change the sibling list of the other jobs when a sibling is disabled' do
        is_expected.to contain_pe_databases__collect('facts').with_sibling_units(siblings['facts'])
      end
    end

    context 'with facts_tables_repack_enabled => false' do
      let(:params) { { facts_tables_repack_enabled: false } }

      it {
        is_expected.to contain_file("#{service_dir}/pe_databases-facts.service").with_ensure('absent')
        ['catalogs', 'other', 'activity'].each do |name|
          is_expected.to contain_file("#{service_dir}/pe_databases-#{name}.service").with_ensure('present')
        end
      }
    end
  end

  context 'with validated parameters' do
    let(:pre_condition) do
      <<-PRE_COND
        define puppet_enterprise::deprecated_parameter() {}

        class { 'pe_databases': manage_database_maintenance => false }
        PRE_COND
    end

    ['max_runtime', 'stop_timeout'].each do |param|
      ['12h', '30s', '1min', '10min', '1min 30s', '1h30m', '1.5h', '30', '2d', '1w', '0'].each do |value|
        context "with #{param} => #{value.inspect}" do
          let(:params) { { param.to_sym => value } }

          it { is_expected.to compile }
        end
      end

      ['', ' ', '12x', '5.5.5', '1..x', 'foo', 'bad;x', '%h', '-1', 'infinity', '1M', "12h\nExecStart=/bin/x", "12h\n30s", ' 12h', "\t12h"].each do |value|
        context "with #{param} => #{value.inspect}" do
          let(:params) { { param.to_sym => value } }

          it { is_expected.to compile.and_raise_error(%r{Pe_databases::Timespan}) }
        end
      end
    end
  end
end
