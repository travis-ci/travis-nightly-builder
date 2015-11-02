begin
  require 'rspec/core/rake_task'
  require 'rubocop/rake_task'
rescue LoadError => e
  warn e
end

require 'json'
require 'faraday'

RuboCop::RakeTask.new if defined?(RuboCop)

RSpec::Core::RakeTask.new if defined?(RSpec)

task default: [:rubocop, :spec]

desc 'Issue build request'
task :build, [:repo, :branch, :extra] do |_t, args|
  $LOAD_PATH.unshift(File.expand_path('../lib', __FILE__))
  require 'travis'

  response = Travis::NightlyBuilder::Runner.new(
    api_endpoint: ENV.fetch('TRAVIS_API_ENDPOINT', 'https://api.travis-ci.org'),
    token: ENV.fetch('TRAVIS_TOKEN')
  ).run(
    repo: args[:repo],
    branch: args[:branch] || 'default',
    env: args[:extra]
  )

  puts response.body
end
