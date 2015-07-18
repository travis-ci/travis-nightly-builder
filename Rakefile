require 'json'
require 'yaml'
require 'open-uri'

desc "Build up build request payload file based on information in .travis.yml"
task :build_payload, [:repo, :branch, :extra] do |t, args|
  repo = args[:repo]
  branch = args[:branch] || 'master'
  config = YAML.load(open("https://raw.githubusercontent.com/travis-ci/#{repo}/#{branch}/.travis.yml"))
  message = "Build repo=#{repo}; branch=#{branch}%s #{Time.now.utc.strftime('%Y-%m-%d-%H-%M-%S')}"
  if args[:extra]
    config["env"]["global"] << args[:extra]
    message = message % ["; (#{args[:extra]})"]
  end

  payload = {
    "request"=> {
      "message"=> message,
      "branch"=>branch,
      "config"=>config
      }
    }
  File.open('payload', 'w') do |f|
    f.puts payload.to_json
  end
end

desc "Issue build request"
task :build, [:repo, :branch, :extra] do |t, args|
  Rake::Task[:build_payload].invoke(args[:repo], args[:branch], args[:extra])
  `curl -s -X POST -H 'Content-Type: application/json' -H "Travis-API-Version: 3" -H 'Authorization: token #{ENV["TRAVIS_TOKEN"]}' -d @payload https://api.travis-ci.org/repo/travis-ci%2F#{args[:repo]}/requests`
end
