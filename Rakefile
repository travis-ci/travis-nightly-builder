require 'json'
require 'yaml'
require 'open-uri'

desc "Build up build request payload file based on information in .travis.yml"
task :build_payload, [:repo] do |t, args|
  puts args
  repo = args[:repo][:repo]
  config = YAML.load(open("https://raw.githubusercontent.com/travis-ci/#{repo}/master/.travis.yml")).to_json
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
task :build, [:repo] do |t, repo|
  Rake::Task[:build_payload].invoke(repo)
  `curl -s -X POST -H Content-Type: application/json -H #{ENV["TRAVIS_TOKEN"]} -d @payload https://api.travis-ci.com/requests`
end
