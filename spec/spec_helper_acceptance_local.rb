# frozen_string_literal: true

require 'singleton'
require 'serverspec'
require 'puppetlabs_spec_helper/module_spec_helper'

class LitmusHelper
  include Singleton
  include PuppetLitmus
end

RSpec.configure do |c|
  c.before :suite do
    LitmusHelper.instance.run_shell('/opt/puppetlabs/bin/puppet plugin download')
    pp = <<-MANIFEST
      package { 'cron':
        ensure => 'latest',
      }
    MANIFEST
    LitmusHelper.instance.apply_manifest(pp)
  end
end
