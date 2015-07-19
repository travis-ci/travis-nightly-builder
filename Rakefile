require 'json'
require 'yaml'
require 'open-uri'
require 'faraday'

desc "Issue build request"
task :build, [:repo, :branch, :extra] do |t, args|
  repo = args[:repo]
  branch = args[:branch] || 'default'

  unless ENV['TRAVIS_TOKEN']
    puts "Env var TRAVIS_TOKEN not set"
    exit 1
  end

  travis_api = 'https://api.travis-ci.org'

  conn = Faraday.new(:url => travis_api) do |faraday|
    faraday.request :url_encoded
    faraday.response :logger
    faraday.adapter Faraday.default_adapter
  end

  message = "Build repo=#{repo}; branch=#{branch}%s #{Time.now.utc.strftime('%Y-%m-%d-%H-%M-%S')}"
  config = {}

  if args[:extra]
    config = {"env" => {"global" => [ args[:extra] ] }}
    message = message % ["; (#{args[:extra]})"]
  else
    message = message % [ nil ]
  end

  payload = {
    "request"=> {
      "message" => message,
      "branch"  => branch,
      "config"  => config
    }
  }

  response = conn.post do |req|
    req.url "/repo/travis-ci%2F#{repo}/requests"
    req.headers['Content-Type'] = 'application/json'
    req.headers['Travis-API-Version'] = '3'
    req.headers['Authorization'] = "token #{ENV["TRAVIS_TOKEN"]}"
    req.body = payload.to_json
  end

  puts response.body
end
