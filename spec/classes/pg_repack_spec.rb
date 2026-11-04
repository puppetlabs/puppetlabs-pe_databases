# frozen_string_literal: true

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
      },
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
    deprecated_params = [
      'pe_databases::pg_repack::reports_tables_repack_timer',
      'pe_databases::pg_repack::resource_events_tables_repack_timer',
    ]
    old_crons = [
      'pg_repack facts tables', 'pg_repack catalogs tables', 'pg_repack other tables',
      'pg_repack reports tables', 'pg_repack resource_events tables',
      'VACUUM FULL facts tables',
      'VACUUM FULL catalogs tables',
      'VACUUM FULL other tables',
      'Maintain PE databases'
    ]

    [:facts, :catalogs, :other, :activity].each do |name|
      context "with the #{name} timer" do
        let(:val) { tables_hash[name] }

        it {
          expect(catalogue).to contain_pe_databases__collect(name).with(
            disable_maintenance: false,
            command: "#{repack_cmd} --elevel DEBUG --echo #{val[:database]}",
            # Strip the backslash character because this is not a regex
            on_cal: val[:schedule].to_s.tr('\\', ''),
          )
        }

        it { expect(catalogue).to contain_service("pe_databases-#{name}.timer").with_ensure('running') }
        it { expect(catalogue).to contain_service("pe_databases-#{name}.service") }

        it {
          expect(catalogue).to contain_file("/etc/systemd/system/pe_databases-#{name}.timer").with_content(%r{OnCalendar=#{val[:schedule]}})
        }

        it {
          expect(catalogue).to contain_file("/etc/systemd/system/pe_databases-#{name}.service").with_content(
            %r{ExecStart=#{repack_cmd} --elevel DEBUG --echo #{val[:database]} #{val[:tables]}},
          )
        }
      end
    end

    deprecated_params.each do |deprecated_param|
      it { expect(catalogue).to contain_puppet_enterprise__deprecated_parameter(deprecated_param) }
    end

    old_crons.each do |cron|
      it { expect(catalogue).to contain_cron(cron).with(ensure: 'absent') }
    end
  end

  context 'when customizing timers' do
    let(:pre_condition) do
      <<-PRE_COND
        define puppet_enterprise::deprecated_parameter() {}

        class {'pe_databases': facts_tables_repack_timer => 'Tue *-*-* 04:20:00'}
      PRE_COND
    end

    it {
      expect(catalogue).to contain_pe_databases__collect('facts').with(
        on_cal: 'Tue *-*-* 04:20:00',
      )
    }
  end

  context 'when customizing log parameters' do
    # Load the rspec hieradata.  This data sets repack_log_level: 'INFO' and enable_echo: false
    let(:hiera_config) { 'hiera-rspec.yaml' }

    it {
      # The command should have --elevel INFO and not contain --echo according to the hieradata
      expect(catalogue).to contain_pe_databases__collect('facts').with(
        command: "#{repack_cmd} --elevel INFO #{tables_hash[:facts][:database]}",
      )
    }

    it {
      # The service file should have --elevel INFO and not contain --echo according to the hieradata
      expect(catalogue).to contain_file('/etc/systemd/system/pe_databases-facts.service').with_content(
        %r{ExecStart=#{repack_cmd} --elevel INFO #{tables_hash[:facts][:database]} #{tables_hash[:facts][:tables]}},
      )
    }
  end
end
