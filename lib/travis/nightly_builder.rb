module Travis
  module NightlyBuilder
    autoload :App, 'travis/nightly_builder/app'
    autoload :Runner, 'travis/nightly_builder/runner'

    def self.config
      @config ||= Config.load
    end
  end
end
