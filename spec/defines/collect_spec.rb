require 'spec_helper'

describe 'pe_databases::collect' do
  context 'when repacking tables' do
    let(:pre_condition) do
      <<-PRE_COND
      define puppet_enterprise::deprecated_parameter() {}
      include pe_databases
      PRE_COND
    end
    let(:title) { 'test' }
    let(:params) do
      {
        command: 'foo',
        on_cal: 'bar',
        tables: ['baz'],
      }
    end

    it {
      is_expected.to contain_service('pe_databases-test.timer').with_ensure('running')
      is_expected.to contain_service('pe_databases-test.service')

      is_expected.to contain_file('/etc/systemd/system/pe_databases-test.timer').with_content(%r{bar})
      is_expected.to contain_file('/etc/systemd/system/pe_databases-test.service').with_content(
        %r{^ExecStart=\S+/repack_run\.sh \S+/repack_cleanup\.sh pe-puppetdb baz -- foo -t baz$},
      )

      is_expected.to contain_service('pe_databases-test.service').that_notifies(
        'Exec[pe_databases_daemon_reload]',
      )
      is_expected.to contain_service('pe_databases-test.timer').that_subscribes_to(
        'File[/etc/systemd/system/pe_databases-test.timer]',
      )
    }
  end

  context 'when disabling maintenance' do
    let(:pre_condition) do
      <<-PRE_COND
      define puppet_enterprise::deprecated_parameter() {}
      include pe_databases
      PRE_COND
    end
    let(:title) { 'test' }
    let(:params) do
      {
        disable_maintenance: true,
        command: 'foo',
        on_cal: 'bar',
        tables: ['baz'],
      }
    end

    it {
      is_expected.to contain_file('/etc/systemd/system/pe_databases-test.timer').with_ensure('absent')
      is_expected.to contain_file('/etc/systemd/system/pe_databases-test.service').with_ensure('absent')
      is_expected.to contain_service('pe_databases-test.timer').with_ensure('stopped')
    }
  end

  context 'when setting runtime limit and cleanup' do
    let(:pre_condition) do
      <<-PRE_COND
      define puppet_enterprise::deprecated_parameter() {}
      include pe_databases
      PRE_COND
    end
    let(:title) { 'test' }
    let(:service_file) { '/etc/systemd/system/pe_databases-test.service' }
    let(:base_params) do
      {
        command: 'foo',
        on_cal: 'bar',
        max_runtime: '3h',
        database: 'pe-puppetdb',
        cleanup_script: '/opt/cleanup.sh',
        wrapper_script: '/opt/run.sh',
        tables: ['baz'],
      }
    end
    let(:params) { base_params }

    it {
      is_expected.to contain_file(service_file).with_content(%r{^TimeoutStartSec=3h$})
      is_expected.to contain_file(service_file).with_content(%r{^TimeoutStopSec=10min$})
      is_expected.to contain_file(service_file).with_content(%r{^KillMode=mixed$})
      is_expected.to contain_file(service_file).with_content(%r{^KillSignal=SIGTERM$})
      is_expected.to contain_file(service_file).without_content(%r{SIGINT})
      is_expected.to contain_file(service_file).with_content(%r{^ExecStart=/opt/run\.sh /opt/cleanup\.sh pe-puppetdb baz -- foo -t baz$})
      is_expected.to contain_file(service_file).with_content(%r{^ExecStartPre=-/opt/cleanup\.sh pe-puppetdb baz$})
      is_expected.to contain_file(service_file).with_content(%r{^ExecStopPost=-/opt/cleanup\.sh pe-puppetdb baz$})
      is_expected.to contain_file(service_file).without_content(%r{RuntimeMaxSec})
      is_expected.to contain_file(service_file).without_content(%r{--siblings})
    }

    context 'with no tables' do
      let(:params) { base_params.merge(tables: []) }

      it {
        is_expected.to contain_file(service_file).with_content(%r{^ExecStartPre=-/opt/cleanup\.sh pe-puppetdb$})
        is_expected.to contain_file(service_file).with_content(%r{^ExecStopPost=-/opt/cleanup\.sh pe-puppetdb$})
        is_expected.to contain_file(service_file).with_content(%r{^ExecStart=/opt/run\.sh /opt/cleanup\.sh pe-puppetdb -- foo\s*$})
        is_expected.to contain_file(service_file).without_content(%r{ExecStart=.* -t })
      }
    end

    context 'with sibling units' do
      let(:params) { base_params.merge(sibling_units: ['pe_databases-x.service', 'pe_databases-y.service']) }

      it {
        is_expected.to contain_file(service_file).with_content(
          %r{^ExecStartPre=-/opt/cleanup\.sh --siblings pe_databases-x\.service,pe_databases-y\.service pe-puppetdb baz$},
        )
        is_expected.to contain_file(service_file).with_content(
          %r{^ExecStopPost=-/opt/cleanup\.sh --siblings pe_databases-x\.service,pe_databases-y\.service pe-puppetdb baz$},
        )
        is_expected.to contain_file(service_file).with_content(
          %r{^ExecStart=/opt/run\.sh /opt/cleanup\.sh --siblings pe_databases-x\.service,pe_databases-y\.service pe-puppetdb baz -- foo -t baz$},
        )
      }

      context 'with no tables' do
        let(:params) { base_params.merge(tables: [], sibling_units: ['pe_databases-x.service']) }

        it {
          is_expected.to contain_file(service_file).with_content(
            %r{^ExecStart=/opt/run\.sh /opt/cleanup\.sh --siblings pe_databases-x\.service pe-puppetdb -- foo\s*$},
          )
          is_expected.to contain_file(service_file).without_content(%r{ -t })
        }
      end
    end

    context 'with a stop timeout' do
      let(:params) { base_params.merge(stop_timeout: '25min') }

      it {
        is_expected.to contain_file(service_file).with_content(%r{^TimeoutStopSec=25min$})
        is_expected.to contain_file(service_file).without_content(%r{TimeoutStopSec=10min})
      }
    end

    context 'with the default wrapper script' do
      let(:params) { base_params.reject { |k, _| k == :wrapper_script } }

      it {
        is_expected.to contain_file(service_file).with_content(
          %r{^ExecStart=/opt/puppetlabs/pe_databases/scripts/repack_run\.sh /opt/cleanup\.sh pe-puppetdb baz -- foo -t baz$},
        )
      }
    end
  end

  context 'with validated parameters' do
    let(:pre_condition) do
      <<-PRE_COND
      define puppet_enterprise::deprecated_parameter() {}
      include pe_databases
      PRE_COND
    end
    let(:title) { 'test' }
    let(:base_params) { { command: 'foo', on_cal: 'bar', tables: ['baz'] } }

    ['max_runtime', 'stop_timeout'].each do |param|
      ['12h', '30s', '1min', '10min', '1min 30s', '1h30m', '1.5h', '30', '2d', '1w', '0'].each do |value|
        context "with #{param} => #{value.inspect}" do
          let(:params) { base_params.merge(param.to_sym => value) }

          it { is_expected.to compile }
        end
      end

      ['', ' ', '12x', '5.5.5', '1..x', 'foo', 'bad;x', '%h', '-1', 'infinity', '1M', "12h\nExecStart=/bin/x", "12h\n30s", ' 12h', "\t12h"].each do |value|
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
