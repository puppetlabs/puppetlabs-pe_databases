require 'spec_helper'

describe 'pe_databases::pg_repack' do
  let(:facts) { { processors: { count: 4 } } }
  let(:repack_cmd) { '/opt/puppetlabs/server/apps/postgresql/11/bin/pg_repack --jobs 1' }
  let(:tables_hash) do
    {
      facts: {
        tables: '-t factsets -t fact_paths',
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

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:pre_condition) do
        <<-PRE_COND
        define puppet_enterprise::deprecated_parameter() {}

        include pe_databases
        PRE_COND
      end
      let(:facts) { os_facts }

      it { is_expected.to compile }
    end
  end

  context 'with default parameters' do
    let(:pre_condition) do
      <<-PRE_COND
      define puppet_enterprise::deprecated_parameter() {}

      include pe_databases
      PRE_COND
    end

    it {
      tables_hash.each do |name, val|
        is_expected.to contain_pe_databases__collect(name).with(
          disable_maintenance: false,
          command: "#{repack_cmd} #{val[:database]}",
          # Strip the backslash character because this is not a regex
          on_cal: (val[:schedule]).to_s.tr('\\', ''),
        )

        is_expected.to contain_service("pe_databases-#{name}.timer").with_ensure('running')
        is_expected.to contain_service("pe_databases-#{name}.service")

        is_expected.to contain_file("/etc/systemd/system/pe_databases-#{name}.timer").with_content(%r{OnCalendar=#{val[:schedule]}})
        is_expected.to contain_file("/etc/systemd/system/pe_databases-#{name}.service").with_content(
          %r{ExecStart=#{repack_cmd} #{val[:database]} #{val[:tables]}},
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
end
