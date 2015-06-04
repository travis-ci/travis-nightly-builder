require 'json'
require 'yaml'
require 'open-uri'

desc "Build up build request payload file based on information in .travis.yml"
task :build_payload, [:repo] do |t, args|
  repo = args[:repo]
  config = YAML.load(open("https://raw.githubusercontent.com/travis-ci/#{repo}/master/.travis.yml"))
  payload = {
    "request"=> {
      "message"=>"Build #{repo}",
      "repository"=>{
        "owner_name"=>"travis-ci",
        "name"=>"#{repo}"
        },
      "branch"=>"master",
      "config"=>config
      }
    }
  File.open('payload', 'w') do |f|
    f.puts payload.to_json
  end
end

desc "Issue build request"
task :build, [:repo] do |t, args|
  Rake::Task[:build_payload].invoke(args[:repo])
  `curl -s -X POST -H 'Content-Type: application/json' -H 'Authorization: token #{ENV["TRAVIS_TOKEN"]}' -d @payload https://api.travis-ci.org/requests`
end
