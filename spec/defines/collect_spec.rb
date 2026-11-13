# frozen_string_literal: true

require 'spec_helper'

COLLECT_SERVICE_FILE = '/etc/systemd/system/pe_databases-test.service'
COLLECT_TIMER_FILE = '/etc/systemd/system/pe_databases-test.timer'
COLLECT_GOOD_TIMESPANS = ['12h', '30s', '1min', '10min', '1min 30s', '1h30m', '1.5h', '30', '2d', '1w', '0'].freeze
COLLECT_BAD_TIMESPANS = ['', ' ', '12x', '5.5.5', '1..x', 'foo', 'bad;x', '%h', '-1', 'infinity', '1M', "12h\nExecStart=/bin/x", "12h\n30s", ' 12h', "\t12h"].freeze

describe 'pe_databases::collect' do
  let(:pre_condition) do
    <<~PRE_COND
      define puppet_enterprise::deprecated_parameter() {}
      include pe_databases
    PRE_COND
  end
  let(:title) { 'test' }
  let(:base_params) do
    {
      command: 'foo',
      on_cal: 'bar',
      tables: ['baz'],
    }
  end
  let(:params) { base_params }

  context 'when repacking tables' do
    it { expect(catalogue).to contain_service('pe_databases-test.timer').with_ensure('running') }
    it { expect(catalogue).to contain_service('pe_databases-test.service') }
    it { expect(catalogue).to contain_file(COLLECT_TIMER_FILE).with_content(%r{bar}) }

    it do
      expect(catalogue).to contain_file(COLLECT_SERVICE_FILE).with_content(
        %r{^ExecStart=\S+/repack_run\.sh \S+/repack_cleanup\.sh pe-puppetdb baz -- foo -t baz$},
      )
    end

    it do
      expect(catalogue).to contain_service('pe_databases-test.service').that_notifies(
        'Exec[pe_databases_daemon_reload]',
      )
    end

    it do
      expect(catalogue).to contain_service('pe_databases-test.timer').that_subscribes_to(
        'File[/etc/systemd/system/pe_databases-test.timer]',
      )
    end
  end

  context 'when disabling maintenance' do
    let(:params) { base_params.merge(disable_maintenance: true) }

    it { expect(catalogue).to contain_file(COLLECT_TIMER_FILE).with_ensure('absent') }
    it { expect(catalogue).to contain_file(COLLECT_SERVICE_FILE).with_ensure('absent') }
    it { expect(catalogue).to contain_service('pe_databases-test.timer').with_ensure('stopped') }
  end

  context 'when setting runtime limit and cleanup' do
    let(:params) do
      base_params.merge(
        max_runtime: '3h',
        database: 'pe-puppetdb',
        cleanup_script: '/opt/cleanup.sh',
        wrapper_script: '/opt/run.sh',
      )
    end

    [
      %r{^TimeoutStartSec=3h$},
      %r{^TimeoutStopSec=10min$},
      %r{^KillMode=mixed$},
      %r{^KillSignal=SIGTERM$},
      %r{^ExecStart=/opt/run\.sh /opt/cleanup\.sh pe-puppetdb baz -- foo -t baz$},
      %r{^ExecStartPre=-/opt/cleanup\.sh pe-puppetdb baz$},
      %r{^ExecStopPost=-/opt/cleanup\.sh pe-puppetdb baz$},
    ].each do |pattern|
      it { expect(catalogue).to contain_file(COLLECT_SERVICE_FILE).with_content(pattern) }
    end

    [%r{SIGINT}, %r{RuntimeMaxSec}, %r{--siblings}].each do |pattern|
      it { expect(catalogue).to contain_file(COLLECT_SERVICE_FILE).without_content(pattern) }
    end

    context 'with no tables' do
      let(:params) do
        base_params.merge(max_runtime: '3h', database: 'pe-puppetdb', cleanup_script: '/opt/cleanup.sh', wrapper_script: '/opt/run.sh', tables: [])
      end

      [
        %r{^ExecStartPre=-/opt/cleanup\.sh pe-puppetdb$},
        %r{^ExecStopPost=-/opt/cleanup\.sh pe-puppetdb$},
        %r{^ExecStart=/opt/run\.sh /opt/cleanup\.sh pe-puppetdb -- foo\s*$},
      ].each do |pattern|
        it { expect(catalogue).to contain_file(COLLECT_SERVICE_FILE).with_content(pattern) }
      end

      it { expect(catalogue).to contain_file(COLLECT_SERVICE_FILE).without_content(%r{ExecStart=.* -t }) }
    end

    context 'with sibling units' do
      let(:params) do
        base_params.merge(
          database: 'pe-puppetdb',
          cleanup_script: '/opt/cleanup.sh',
          wrapper_script: '/opt/run.sh',
          sibling_units: ['pe_databases-x.service', 'pe_databases-y.service'],
        )
      end

      [
        %r{^ExecStartPre=-/opt/cleanup\.sh --siblings pe_databases-x\.service,pe_databases-y\.service pe-puppetdb baz$},
        %r{^ExecStopPost=-/opt/cleanup\.sh --siblings pe_databases-x\.service,pe_databases-y\.service pe-puppetdb baz$},
        %r{^ExecStart=/opt/run\.sh /opt/cleanup\.sh --siblings pe_databases-x\.service,pe_databases-y\.service pe-puppetdb baz -- foo -t baz$},
      ].each do |pattern|
        it { expect(catalogue).to contain_file(COLLECT_SERVICE_FILE).with_content(pattern) }
      end
    end

    context 'with sibling units and no tables' do
      let(:params) do
        base_params.merge(
          database: 'pe-puppetdb',
          cleanup_script: '/opt/cleanup.sh',
          wrapper_script: '/opt/run.sh',
          tables: [],
          sibling_units: ['pe_databases-x.service'],
        )
      end

      it do
        expect(catalogue).to contain_file(COLLECT_SERVICE_FILE).with_content(
          %r{^ExecStart=/opt/run\.sh /opt/cleanup\.sh --siblings pe_databases-x\.service pe-puppetdb -- foo\s*$},
        )
      end

      it { expect(catalogue).to contain_file(COLLECT_SERVICE_FILE).without_content(%r{ -t }) }
    end

    context 'with a stop timeout' do
      let(:params) { base_params.merge(database: 'pe-puppetdb', cleanup_script: '/opt/cleanup.sh', stop_timeout: '25min') }

      it { expect(catalogue).to contain_file(COLLECT_SERVICE_FILE).with_content(%r{^TimeoutStopSec=25min$}) }
      it { expect(catalogue).to contain_file(COLLECT_SERVICE_FILE).without_content(%r{TimeoutStopSec=10min}) }
    end

    context 'with the default wrapper script' do
      let(:params) { base_params.merge(database: 'pe-puppetdb', cleanup_script: '/opt/cleanup.sh') }

      it do
        expect(catalogue).to contain_file(COLLECT_SERVICE_FILE).with_content(
          %r{^ExecStart=/opt/puppetlabs/pe_databases/scripts/repack_run\.sh /opt/cleanup\.sh pe-puppetdb baz -- foo -t baz$},
        )
      end
    end
  end

  context 'with validated parameters' do
    ['max_runtime', 'stop_timeout'].each do |param|
      COLLECT_GOOD_TIMESPANS.each do |value|
        context "with #{param} => #{value.inspect}" do
          let(:params) { base_params.merge(param.to_sym => value) }

          it { is_expected.to compile }
        end
      end

      COLLECT_BAD_TIMESPANS.each do |value|
        context "with #{param} => #{value.inspect}" do
          let(:params) { base_params.merge(param.to_sym => value) }

          it { is_expected.to compile.and_raise_error(%r{Pe_databases::Timespan}) }
        end
      end
    end

    ['pe-puppetdb', 'pe-activity'].each do |value|
      context "with database => #{value.inspect}" do
        let(:params) { base_params.merge(database: value) }

        it { is_expected.to compile }
      end
    end

    ['', '-pe', 'pe puppetdb', "pe-puppetdb\nx", 'pe;x'].each do |value|
      context "with database => #{value.inspect}" do
        let(:params) { base_params.merge(database: value) }

        it { is_expected.to compile.and_raise_error(%r{Pe_databases::Database_name}) }
      end
    end
  end
end
