require 'json'
require 'sinatra/base'
require 'sinatra/param'
require 'sinatra/contrib'
require 'google/cloud/storage'
require 'redis'
require 'travis/logger'

require_relative 'runner'

module Travis
  module NightlyBuilder
    class App < Sinatra::Base
      class << self
        def auth_tokens
          @auth_tokens ||= (ENV['AUTH_TOKENS'] || '').split(':').map(&:strip)
        end

        def base_env
          @base_env ||= Hash[ENV]
        end
      end

      unless development? || test?
        require 'rack/auth/basic'

        use Rack::Auth::Basic, 'Nightly Builder Realm' do |_, password|
          App.auth_tokens.include?(password)
        end

        require 'rack/ssl'

        use Rack::SSL
      end

      helpers Sinatra::Param

      attr_reader :archives

      get '/hello' do
        "ohai\n"
      end

      get /\/builds(?:\/([^\/]+)(?:\/([^\/]+)(?:\/([^\/]+)(?:\/(.*))?)?)?)?\/?/ do
        # /builds/:lang
        # /builds/:lang/:os
        # /builds/:lang/:os/:release
        # /builds/:lang/:os/:release/:arch
        @archives = files(params['captures'].compact)

        types = %w[text/html application/json application/x-yaml text/yaml]

        case request.preferred_type(types)
        when 'application/json'
          content_type 'application/json'
          archives.map(&:to_h).to_json
        when 'application/x-yaml', 'text/yaml'
          content_type 'text/yaml'
          archives.map(&:to_h).to_yaml
        else
          slim :index
        end
      end

      post '/build' do
        param :branch, String, default: 'default'
        param :env, Array, default: []
        param :source, String, default: ENV['DYNO']

        overridable = %w(os dist arch)

        logger.info "params=#{params.inspect}"

        form_data = params.select {|k, v| overridable.include?(k) && !v.to_s.empty?}
        env_arg = "VERSION=#{params['version']}"
        env_arg += " ALIAS=#{params['alias']}" unless params['alias'].to_s.empty?
        env = [params['env'], env_arg].reject(&:empty?).compact.join(" ")

        logger.info "form_data=#{form_data} env=#{env.inspect}"

        results = runner.run(
          repo: params['repo'],
          branch: params['branch'],
          env: env,
          source: params['source'],
          override: form_data
        )

        halt 400 unless results.success?

        build = JSON.parse(results.body).fetch('builds').first

        redirect "https://travis-ci.com/#{runner.owner}/#{params['repo']}/builds/#{build['id']}"
      end

      run! if app_file == $PROGRAM_NAME

      private

      def runner
        @runner ||= Runner.new(
          api_endpoint: ENV.fetch('TRAVIS_API_ENDPOINT'),
          token: ENV.fetch('TRAVIS_TOKEN')
        )
      end

      def logger
        @logger ||= Travis::Logger.new(STDOUT)
        @logger.level = Logger.const_get(ENV.fetch("LOG_LEVEL", "INFO").upcase)
        @logger
      end

      def gcs_viewer
        @viewer ||= Google::Cloud::Storage.new(
          project_id: ENV.fetch('TRAVIS_GCS_PROJECT_ID'),
          credentials: gcs_read_creds
        )
      end

      def redis
        @redis ||= Redis.new
      end

      def gcs_read_creds
        JSON.load(ENV.fetch('TRAVIS_GCS_CRED_JSON'))
      end

      def files(parts)
        prefix = if parts.length > 1
          parts.insert(1, 'binaries').compact.join("/")
        else
          parts.first
        end

        if Time.now.to_i >= redis.get("#{prefix}:last_checked_at").to_i + 60*60*2 # 2 hours ago
          gcs_viewer.bucket('travis-ci-language-archives')
          .files(prefix: prefix)
          .all
          .select {|x| x.name.end_with?('.bz2')}
          .map do |x|
            lang, _, os, release, arch, file_name = x.name.split('/')
            { 'lang' => lang, 'os' => os, 'release' => release, 'arch' => arch, 'name' => file_name }
          end.tap do |x|
            redis.set "#{prefix}:last_checked_at", Time.now.to_i
            redis.set "#{prefix}:files", x.to_json
          end
        else
          JSON.load(redis.get "#{prefix}:files")
        end
      end

    end
  end
end
