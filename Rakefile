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
require 'ostruct'
require 'term/ansicolor'

BUCKET_PREFIX = {
  precise: 'binaries/ubuntu/12.04/x86_64/',
  trusty:  'binaries/ubuntu/14.04/x86_64/',
  xenial:  'binaries/ubuntu/16.04/x86_64/',
  bionic:  'binaries/ubuntu/18.04/x86_64/',
  mountain_lion: 'binaries/osx/10.8/x86_64/',
  mavericks:     'binaries/osx/10.9/x86_64/',
  yosemite:      'binaries/osx/10.10/x86_64/',
  el_capitan:    'binaries/osx/10.11/x86_64/',
  sierra:        'binaries/osx/10.12/x86_64/',
  high_sierra:   'binaries/osx/10.13/x86_64/',
}

LANGUAGES = [
  'perl',
  'perl-extras',
  'python',
  'pypy2.7',
  'pypy3.5',
  'pypy3.6',
  'php',
  'erlang',
  'ruby',
]

RUNTIMES = {
  'perl' => OpenStruct.new(
    archive_bucket: 'travis-perl-archives',
    builder_repo: 'perl-builder',
    builder_branch: 'master',
    repo: 'Perl/perl5',
    api_path: 'repos/Perl/perl5/tags',
    version_prefix: 'v',
    except: 'v(\d+)\.\d*[13579](\.\d+)(-RC\d+)?$',
    supported_major_minor: %w(5.24 5.26 5.27 5.28 5.29 5.30),
  ),
  'perl-extras' => OpenStruct.new(
    archive_bucket: 'travis-perl-archives',
    builder_repo: 'perl-builder',
    builder_branch: 'master',
    repo: 'Perl/perl5',
    api_path: 'repos/Perl/perl5/tags',
    version_prefix: 'v',
    except: 'v(\d+)\.\d*[13579](\.\d+)(-RC\d+)?$',
    supported_major_minor: %w(5.24 5.26 5.28 5.30),
  ),
  'python' => OpenStruct.new(
    archive_bucket: 'travis-python-archives',
    builder_repo: 'cpython-builder',
    builder_branch: 'default',
    repo: 'pyenv/pyenv',
    api_path: "repos/pyenv/pyenv/git/trees/master?recursive=1",
    path: 'plugins/python-build/share/python-build',
    version_prefix: '',
    except: '(-dev|rc\d+)$',
    supported_major_minor: %w(2.7 3.5 3.6 3.7 3.8),
  ),
  'pypy2.7'   => OpenStruct.new(
    archive_bucket: 'travis-python-archives',
    builder_repo: 'cpython-builder',
    builder_branch: 'default',
    repo: 'pyenv/pyenv',
    api_path: "repos/pyenv/pyenv/git/trees/master?recursive=1",
    path: 'plugins/python-build/share/python-build',
    version_prefix: 'pypy2.7-',
    except: '(-(alpha|beta)\d*|-src)$',
    supported_major_minor: %w(5.9 5.10 6.0 7.0 7.1 7.2 7.3),
  ),
  'pypy3.5'   => OpenStruct.new(
    archive_bucket: 'travis-python-archives',
    builder_repo: 'cpython-builder',
    builder_branch: 'default',
    repo: 'pyenv/pyenv',
    api_path: "repos/pyenv/pyenv/git/trees/master?recursive=1",
    path: 'plugins/python-build/share/python-build',
    version_prefix: 'pypy3.5-',
    except: '(-(alpha|beta)\d*|-src)$',
    supported_major_minor: %w(5.9 5.10 6.0 7.0),
  ),
  'pypy3.6'   => OpenStruct.new(
    archive_bucket: 'travis-python-archives',
    builder_repo: 'cpython-builder',
    builder_branch: 'default',
    repo: 'pyenv/pyenv',
    api_path: "repos/pyenv/pyenv/git/trees/master?recursive=1",
    path: 'plugins/python-build/share/python-build',
    version_prefix: 'pypy3.6-',
    except: '(-(alpha|beta)\d*|-src)$',
    supported_major_minor: %w(7.0 7.1 7.2 7.3),
  ),
  'php'    => OpenStruct.new(
    archive_bucket: 'travis-php-archives',
    builder_repo: 'php-src-builder',
    builder_branch: 'default',
    repo: 'php-build/php-build',
    api_path: "repos/php-build/php-build/git/trees/master?recursive=1",
    path: 'share/php-build/definitions',
    version_prefix: '',
    supported_major_minor: %w(5.6 7.0 7.1 7.2 7.3 7.4),
  ),
  'erlang' => OpenStruct.new(
    archive_bucket: 'travis-otp-releases',
    builder_repo: 'travis-erlang-builder',
    builder_branch: 'master',
    repo: 'erlang/otp',
    api_path: 'repos/erlang/otp/tags',
    version_prefix: 'OTP[-_]',
    supported_major_minor: ['19.3', '20.0', '20.1', '20.2', '20.3', '21.0', '21.1', '21.2', '21.3', '22.0', '22.1', '22.2', '22.3', '23.0'],
    pass_through_release_name: true,
    skip_matching_alias: true
  ),
  'ruby' => OpenStruct.new(
    archive_bucket: 'travis-rubies',
    builder_repo: 'travis-rubies',
    builder_branch: 'build',
    repo: 'ruby/ruby',
    api_path: 'repos/ruby/ruby/tags?per_page=100',
    version_prefix: 'v',
    supported_major_minor: ['2.2', '2.3', '2.4', '2.5', '2.6', '2.7'],
    pass_through_release_name: true,
    skip_matching_alias: true,
    release_transformer: -> before { before.gsub('_', '.') },
  ),
}

SUPPORTED_OS = {
  'perl'   => %i(precise trusty xenial bionic),
  'perl-extras'   => %i(precise trusty xenial bionic),
  'python' => %i(precise trusty xenial bionic),
  'pypy2.7'   => %i(precise trusty xenial bionic),
  'pypy3.5'   => %i(precise trusty xenial bionic),
  'pypy3.6'   => %i(trusty xenial bionic),
  'php'    => %i(precise trusty xenial bionic),
  'erlang' => %i(precise trusty xenial bionic),
  'ruby' => %i(precise trusty xenial bionic),
}

RuboCop::RakeTask.new if defined?(RuboCop)

RSpec::Core::RakeTask.new if defined?(RSpec)

include Term::ANSIColor

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
task :build, [:repo, :branch, :extra, :override] do |_t, args|
  $LOAD_PATH.unshift(File.expand_path('../lib', __FILE__))
  require 'travis'

  logger.info "args=#{args}"
  repo = args[:repo]
  branch = args.fetch(:branch, 'default')

  response = Travis::NightlyBuilder::Runner.new(
    api_endpoint: ENV.fetch('TRAVIS_API_ENDPOINT', 'https://api.travis-ci.com')
  ).run(
    repo: repo,
    branch: branch,
    env: args[:extra],
    override: parse_filter(args.fetch(:override, ''))
  )

  logger.info "response=#{response.body}"

  if response.success?
    build = JSON.parse(response.body).fetch('builds').first
    logger.info "#{green}#{bold} https://travis-ci.com/travis-ci/#{repo}/builds/#{build['id']} #{reset}"
  end
end

def parse_filter(str)
  str.split(";").map {|x| x.split "="}.to_h
end

def version_regex(runtime)
  /^#{runtime}-(\d+(?:\.\d+)*.*)\.tar\.(gz|bz2)/
end

def latest_releases_for(lang)
  runtime = RUNTIMES.fetch lang
  conn = Faraday.new(url: 'https://api.github.com') do |f|
    f.use FaradayMiddleware::FollowRedirects, limit: 5
    f.use Faraday::Request::Authorization, 'Token', ENV['GITHUB_TOKEN'] if ENV['GITHUB_TOKEN']
    f.adapter Faraday.default_adapter
  end

  logger.debug "url=#{runtime.api_path} runtime=#{runtime}"
  response = conn.get runtime.api_path

  unless response.success?
    logger.info "response=#{response.status}"
    return
  end

  json_data = JSON.load(response.body)

  logger.debug "json_data=#{json_data}"

  if json_data.respond_to?(:key?) && json_data.key?("tree")
    defs = json_data["tree"].select do |obj|
      obj["path"].match %r(^#{runtime.path}/#{runtime.version_prefix}\d)
    end
  else
    defs = json_data.select do |obj|
      (obj["tag_name"] || obj["name"]).match %r(^#{runtime.version_prefix}\d)
    end
  end

  if runtime.except
    defs.reject! {|obj| (obj["tag_name"] || obj["name"] || obj["path"] || '').match %r(#{runtime.except})}
  end

  logger.debug "defs=#{defs}"

  transformer = runtime.release_transformer

  defs.sort! do |x,y|
    name1 = release_name(x)
    name2 = release_name(y)
    if transformer
      name1 = transformer.call(name1)
      name2 = transformer.call(name2)
    end

    vers1 = name1.match(%r(#{runtime.version_prefix}(\d+(\.\d+)?.*\z)))[1]
    vers2 = name2.match(%r(#{runtime.version_prefix}(\d+(\.\d+)?.*\z)))[1]

    Gem::Version.new(vers1) <=> Gem::Version.new(vers2)
  end

  if transformer
    defs.map! do |entity|
      entity["name"] = transformer.call(entity["name"])
      entity
    end
  end

  logger.debug "defs_after=#{defs}"

  groups = defs.group_by do |x|
    name = release_name(x)
    name.match(%r(#{runtime.version_prefix}((\d+(([\._])\d+))(\4\d+)*.*\z)))[2]
  end
end

def latest_archives_for(runtime)
  latest_versions = {}

  stuff = SUPPORTED_OS.fetch(runtime).map {|os| BUCKET_PREFIX.fetch(os)}.map do |prefix|
    bucket = RUNTIMES.fetch(runtime).archive_bucket
    archives = `aws s3 ls s3://#{bucket}/#{prefix} | awk '{print $NF}'`.split

    fail "Could not fetch archives list for #{runtime}" if archives.empty?

    versions = archives.map do |archive|
      if RUNTIMES.fetch(runtime).skip_matching_alias
        md = archive.match /^#{runtime}-(?<version>\d+(\.\d+)(\.\d+)*)\.tar\.bz2/
      else
        case runtime
        when /extras$/
          md = archive.match /^#{runtime}-(?<version>\d+(\.\d+)(\.\d+)+)-extras\.tar\.bz2/
        else
          md = archive.match /^#{runtime}-(?<version>\d+(\.\d+)(\.\d+)+)\.tar\.bz2/
        end
      end
      md && md[:version]
    end.compact

    # group by MAJOR.MINOR
    version_groups = versions.group_by {|v| RUNTIMES.fetch(runtime).skip_matching_alias ? v.match(/^(\d+\.\d+)(\.\d+)*/)[1] : v.match(/^(\d+\.\d+)(\.\d+)+/)[1] }

    version_groups.each do |v, versions|
      latest_versions[v] = versions.sort { |a,b| Gem::Version.new(a) <=> Gem::Version.new(b) }.last
    end
  end

  latest_versions
end

def release_name(release)
  name = release.key?("path") && release["path"].split('/').last || release["tag_name"] || release["name"]
end

desc 'Build latest archives for language'
task :build_latest_archives do |_t, args|
  LANGUAGES.each do |lang|
    logger.info "Building latest archives for #{lang}"
    runtime = RUNTIMES.fetch(lang)

    latest_releases ||= latest_releases_for(lang)
    latest_archives ||= latest_archives_for(lang)

    latest_supported_releases = latest_releases.select do |major_minor, releases|
      runtime.supported_major_minor.any? { |supported| major_minor.start_with? supported }
    end

    logger.debug "latest_releases=#{latest_releases}"
    logger.debug "latest_supported_releases=#{latest_supported_releases}"

    next if latest_supported_releases.empty?

    runtime.supported_major_minor.each do |major_minor|
      next unless latest_supported_releases[major_minor]

      latest_supported_release = latest_supported_releases[major_minor].last
      vers = latest_release_name = release_name(latest_supported_release)

      logger.debug "latest_supported_release=#{latest_supported_release}"
      logger.debug "vers=#{vers}"

      if runtime.version_prefix && !runtime.version_prefix.empty?
        md = /^(?<version_prefix>#{runtime.version_prefix})(?<vers>\d+(\.\d+)*)/.match(latest_release_name)
        vers = md[:vers]
        latest_release_name = runtime.version_prefix + vers
      end

      unless runtime.pass_through_release_name
        md = /^(?<version_prefix>#{runtime.version_prefix})(?<vers>\d+(\.\d+)*)/.match(release_name(latest_releases[major_minor].last))
        vers = md[:vers]
      end

      logger.info "latest_archives[major_minor]=#{latest_archives[major_minor]}"
      logger.info "vers=#{vers}"

      if Gem::Version.new(latest_archives.fetch(major_minor, '')) >= Gem::Version.new(vers)
        logger.info "#{lang} #{major_minor} is up to date (#{vers})"
        next
      end

      case lang
      when 'ruby'
        rake_task_vars = " RUBY=#{vers}"
      when /^pypy/
        rake_task_vars = "VERSION=#{lang}-#{vers}"
        if major_minor == runtime.supported_major_minor.last
          alias_ = lang.start_with? ("pypy3") ? 'pypy3' : lang
          rake_task_vars += " ALIAS=#{alias_}"
        end
      when "perl-extras"
        rake_task_vars = "VERSION=#{vers} NAME=#{vers}-extras ALIAS='#{vers}-shrplib #{major_minor}-shrplib #{major_minor}-shrplib' ARGS='-Duseshrplib -Duseithreads'"
      when 'erlang'
        rake_task_vars = "VERSION=#{vers}"
      else
        rake_task_vars = "VERSION=#{vers}"
        rake_task_vars += " ALIAS=#{major_minor}"
      end

      logger.info "vers=#{vers}"
      logger.info "latest_release_name=#{latest_release_name}"
      logger.info "rake_task_vars=#{rake_task_vars}"

      Rake::Task["build"].invoke(runtime.builder_repo, runtime.builder_branch, rake_task_vars)
      Rake::Task["build"].reenable
    end
  end
end
