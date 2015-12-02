require 'json'
require 'faraday'

desc 'Issue build request'
task :build, [:repo, :branch, :extra] do |_t, args|
  repo = args[:repo]
  branch = args[:branch] || 'default'

  unless ENV['TRAVIS_TOKEN']
    puts 'Env var TRAVIS_TOKEN not set'
    exit 1
  end

  travis_api = ENV['TRAVIS_API_ENDPOINT'] || 'https://api.travis-ci.org'

  conn = Faraday.new(url: travis_api) do |faraday|
    faraday.request :url_encoded
    faraday.response :logger
    faraday.adapter Faraday.default_adapter
  end

  message = ENV['TRAVIS_MESSAGE'] || "Build repo=#{repo}; branch=#{branch}%s " \
            "#{Time.now.utc.strftime('%Y-%m-%d-%H-%M-%S')}"
  owner = ENV['REPO_OWNER'] || 'travis-ci'
  config = {}

  if args[:extra]
    config = { 'env' => { 'global' => args[:extra].scan(/[^\s=]+=(?:'[^']*'|[^\s=]+)/) } }
    message = format(message, "; (#{args[:extra]})")
  else
    message = format(message, nil)
  end

  response = conn.post do |req|
    req.url "/repo/#{owner}%2F#{repo}/requests"
    req.headers['Content-Type'] = 'application/json'
    req.headers['Travis-API-Version'] = '3'
    req.headers['Authorization'] = "token #{ENV['TRAVIS_TOKEN']}"
    req.body = {
      request: {
        message: message,
        branch: branch,
        config: config
      }
    }.to_json
  end

  puts response.body
end
