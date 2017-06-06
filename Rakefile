begin
  require 'rspec/core/rake_task'
  require 'rubocop/rake_task'
rescue LoadError => e
  warn e
end

require 'json'
require 'faraday'
require 'faraday_middleware'
require 'rubygems'
require 'logger'
require 'pp'
require 'yaml'

Runtime = Struct.new(:archive_bucket, :builder_repo, :builder_branch, :repo, :api_path, :path, :prefix, :except)

BUCKET_PREFIX = {
  precise: 'binaries/ubuntu/12.04/x86_64/',
  trusty:  'binaries/ubuntu/14.04/x86_64/',
  mountain_lion: 'binaries/osx/10.8/x86_64/',
  mavericks:     'binaries/osx/10.9/x86_64/',
  yosemite:      'binaries/osx/10.10/x86_64/',
  el_capitan:    'binaries/osx/10.11/x86_64/',
  sierra:        'binaries/osx/10.12/x86_64/',
}

RUNTIMES = {
  'perl' => Runtime.new(
    'travis-perl-archives',
    'perl-builder',
    'master',
    'Perl/perl5',
    'repos/Perl/perl5/tags',
    nil,
    'v',
    'v(\d+)\.\d*[13579](\.\d+)(-RC\d+)?$'
  ),
  'python' => Runtime.new(
    'travis-python-archives',
    'cpython-builder',
    'default',
    'yyuu/pyenv',
    "repos/yyuu/pyenv/git/trees/master?recursive=1",
    'plugins/python-build/share/python-build',
    '',
    '-dev$'
  ),
  'pypy'   => Runtime.new(
    'travis-python-archives',
    'cpython-builder',
    'default',
    'yyuu/pyenv',
    "repos/yyuu/pyenv/git/trees/master?recursive=1",
    'plugins/python-build/share/python-build',
    'pypy-'
  ),
  'php'    => Runtime.new(
    'travis-php-archives',
    'php-src-builder',
    'default',
    'php-build/php-build',
    "repos/php-build/php-build/git/trees/master?recursive=1",
    'share/php-build/definitions',
    ''
  ),
  'erlang' => Runtime.new(
    'travis-otp-releases',
    'travis-erlang-builder',
    'master',
    'erlang/otp',
    'repos/erlang/otp/tags',
    nil, # path
    'OTP[-_]'
  ),
}

SUPPORTED_OS = {
  'perl'   => %i(precise trusty),
  'python' => %i(precise trusty),
  'pypy'   => %i(precise trusty),
  'php'    => %i(precise trusty),
  'erlang' => %i(precise trusty),
}

RuboCop::RakeTask.new if defined?(RuboCop)

RSpec::Core::RakeTask.new if defined?(RSpec)

def latest_archives
  @latest_archives
end

def latest_archives=(other)
  @latest_archives = other
end

def latest_releases
  @latest_releases
end

def latest_releases=(other)
  @latest_releases = other
end

def logger
  @logger ||= Logger.new(STDERR)
  @logger.level = Logger.const_get(ENV.fetch("LOG_LEVEL", "INFO").upcase)
  @logger
end

task default: [:rubocop, :spec]

desc 'Issue build request'
task :build, [:repo, :branch, :extra] do |_t, args|
  $LOAD_PATH.unshift(File.expand_path('../lib', __FILE__))
  require 'travis'

  logger.info "args=#{args}"

  response = Travis::NightlyBuilder::Runner.new(
    api_endpoint: ENV.fetch('TRAVIS_API_ENDPOINT', 'https://api.travis-ci.org'),
    token: ENV.fetch('TRAVIS_TOKEN')
  ).run(
    repo: args[:repo],
    branch: args[:branch] || 'default',
    env: args[:extra]
  )

  logger.info "response=#{response.body}"
end

def version_regex(runtime)
  /^#{runtime}-(\d+(?:\.\d+)*.*)\.tar\.(gz|bz2)/
end

def latest_releases_for(runtime)
  conn = Faraday.new(url: 'https://api.github.com') do |f|
    f.use FaradayMiddleware::FollowRedirects, limit: 5
    f.use Faraday::Request::Authorization, 'Token', ENV['GITHUB_TOKEN'] if ENV['GITHUB_TOKEN']
    f.adapter Faraday.default_adapter
  end

  logger.debug "url=#{RUNTIMES[runtime].api_path} runtime=#{RUNTIMES[runtime]}"
  response = conn.get RUNTIMES[runtime].api_path

  unless response.success?
    logger.info "response=#{response.status}"
    return
  end

  json_data = JSON.load(response.body)

  if json_data.respond_to?(:key?) && json_data.key?("tree")
    defs = json_data["tree"].select do |obj|
      obj["path"].match %r(^#{RUNTIMES[runtime].path}/#{RUNTIMES[runtime].prefix}\d)
    end
  else
    defs = json_data.select do |obj|
      (obj["tag_name"] || obj["name"]).match %r(^#{RUNTIMES[runtime].prefix}\d)
    end
  end

  if RUNTIMES[runtime].except
    defs.reject! {|obj| (obj["tag_name"] || obj["name"] || obj["path"] || '').match %r(#{RUNTIMES[runtime].except})}
  end

  defs.sort! do |x,y|
    name1 = x.key?("path") && x["path"].split('/').last || x["tag_name"] || x["name"]
    name2 = y.key?("path") && y["path"].split('/').last || y["tag_name"] || y["name"]

    vers1 = name1.match(%r(#{RUNTIMES[runtime].prefix}(\d+(\.\d+)?.*\z)))[1]
    vers2 = name2.match(%r(#{RUNTIMES[runtime].prefix}(\d+(\.\d+)?.*\z)))[1]

    Gem::Version.new(vers1) <=> Gem::Version.new(vers2)
  end

  groups = defs.group_by do |x|
    name = x.key?("path") && x["path"].split('/').last || x["tag_name"] || x["name"]
    name.match(%r(#{RUNTIMES[runtime].prefix}((\d+(\.\d))(\.\d)*.*\z)))[2]
  end

  groups.values.map(&:last).map do |x|
    x.key?("path") && x["path"].split('/').last || x["tag_name"] || x["name"]
  end
end

def latest_archives_for(runtime)
  latest_versions = {}

  stuff = SUPPORTED_OS['python'].map {|os| BUCKET_PREFIX[os]}.map do |prefix|
    bucket = RUNTIMES[runtime].archive_bucket
    archives = `aws s3 ls s3://#{bucket}/#{prefix} | awk '{print $NF}'`.split

    versions = archives.map do |archive|
      md = archive.match /^#{runtime}-(?<version>\d+(\.\d+)(\.\d+)+)\.tar\.bz2/
      md && md[:version]
    end.compact

    # group by MAJOR.MINOR
    version_groups = versions.group_by {|v| v.match(/^(\d+\.\d+)(\.\d+)+/)[1] }

    version_groups.each do |v, versions|
      latest_versions[v] = versions.sort { |a,b| Gem::Version.new(a) <=> Gem::Version.new(b) }.last
    end
  end

  latest_versions
end

desc 'Ensure "aws" CLI client is available'
task :ensure_aws do
  unless `command -v aws >& /dev/null`
    system "pip install aws"
  end
end

desc 'Build latest archives for language'
task :build_latest_archives, [:runtime] do |_t, args|
  runtime = args[:runtime]

  latest_releases ||= latest_releases_for(runtime)
  latest_archives ||= latest_archives_for(runtime)
  logger.info "latest_release=#{latest_releases}"
  logger.info "latest_archives=#{latest_archives}"

  latest_releases.each do |v|
    next unless v.match(/\d+(\.\d+)*/)

    if md = v.match(/(?<major_minor>\d+\.\d+)(?<teeny>\.\d+)*(?<extra>.*)$/)
      latest_release_version = Gem::Version.new(md[0])
      if latest_archives.values.all? { |archive_version| latest_release_version > Gem::Version.new(archive_version) }
        logger.info "latest_release=#{latest_release_version}"
        logger.info "VERSION=#{md[0]} ALIAS=#{md[:major_minor]}"
        rake_task_vars = "VERSION=#{md[0]}"
        rake_task_vars += " ALIAS=#{md[:major_minor]}" if md[:major_minor]
        Rake::Task["build"].invoke(RUNTIMES[runtime].builder_repo, RUNTIMES[runtime].builder_branch, rake_task_vars)
        Rake::Task["build"].reenable
      end
    end
  end

  latest_archives.each do |major_minor, version|
    if latest_release = latest_releases.find {|v| v =~ /^#{major_minor}/}
      logger.info "latest_release=#{latest_release} latest_archive=#{latest_archives[major_minor]}"
      if Gem::Version.new(latest_release) > Gem::Version.new(latest_archives[major_minor])
        Rake::Task["build"].invoke(RUNTIMES[runtime].builder_repo, RUNTIMES[runtime].builder_branch, "VERSION=#{latest_release} ALIAS=#{major_minor}")
        Rake::Task["build"].reenable
      end
    end
  end
end
