require 'json'
require 'sinatra/base'
require 'sinatra/param'
require 'sinatra/contrib'
require 'google/cloud/storage'
require 'redis'
require 'travis/logger'
require 'travis/sso'
require 'travis/config'

require_relative 'runner'

module Travis
  module NightlyBuilder
    class App < Sinatra::Base
      unless development? || test?
        require 'rack/ssl'
        use Rack::SSL
      end

      UNAUTHENTICATED_CONTENT_TYPES = %w[
        application/json
        application/x-yaml
        text/yaml
      ]

      enable :method_override, :sessions
      set session_secret: Travis::NightlyBuilder.config.session_secret, static: false

      if development? || test?
        define_method(:current_user) do
          OpenStruct.new(login: 'test_user')
        end
      else
        set :sso,
          mode: :session,
          authenticated?: -> r {
            redis = Redis.new
            r.session['user_login'] &&
            redis.exists("user_token:#{r.session['user_login']}")
          },
          whitelisted?: -> r { r.path == '/hello' || ( r.get? && UNAUTHENTICATED_CONTENT_TYPES.include?(r.get_header("HTTP_ACCEPT"))) },
          set_user: -> r, u {
            redis = Redis.new
            r.session['user_login'] = u['login']
            redis.set "user_token:#{u['login']}", u['token'], ex: 48*24*60*60 # 48 days
          },
          user_id_key: 'user_login',
          endpoint: Travis::NightlyBuilder.config.api_endpoint || 'https://api.travis-ci.com'
        register Travis::SSO
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

        types = %w[text/html] + UNAUTHENTICATED_CONTENT_TYPES

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
        halt 401 unless admin?

        logger.debug "session_keys=#{session.keys}"

        param :branch, String, default: 'default'
        param :env, Array, default: []
        param :source, String, default: ENV['DYNO']

        overridable = %w(os dist osx_image arch)

        logger.debug "params=#{params.inspect}"

        form_data = params.select {|k, v| overridable.include?(k) && !v.to_s.empty?}
        env_arg = "VERSION=#{params['version']}"
        env_arg += " ALIAS=#{params['alias']}" unless params['alias'].to_s.empty?
        env = [params['env'], env_arg].reject(&:empty?).compact.join(" ")

        logger.debug "form_data=#{form_data} env=#{env.inspect}"

        results = runner.run(
          repo: params['repo'],
          token: user_token_for(current_user.login),
          branch: params['branch'],
          env: env,
          source: params['source'],
          override: form_data
        )

        halt 400 unless results.success?

        build = JSON.parse(results.body).fetch('builds').first

        redirect "https://app.travis-ci.com/#{runner.owner}/#{params['repo']}/builds/#{build['id']}"
      end

      run! if app_file == $PROGRAM_NAME

      def admin?
        if self.class.production? && current_user.login
          admins.include? current_user.login
        elsif self.class.development?
          true
        else
          false
        end
      end

      def admins
        Travis::NightlyBuilder.config.admins || []
      end

      private

      def runner
        @runner ||= Runner.new(
          api_endpoint: ENV.fetch('TRAVIS_API_ENDPOINT')
        )
      end

      def logger
        @logger ||= Travis::Logger.new(STDOUT)
        @logger.level = Logger.const_get(ENV.fetch("LOG_LEVEL", "INFO").upcase)
        @logger
      end

      def gcs_viewer
        @viewer ||= Google::Cloud::Storage.new(
          project_id: gcs_project_id,
          credentials: gcs_read_creds
        )
      end

      def redis
        @redis ||= Redis.new
      end

      def gcs_project_id
        Travis::NightlyBuilder.config.gcs.project_id
      rescue
        ENV.fetch('TRAVIS_GCS_PROJECT_ID')
      end

      def gcs_read_creds
        JSON.load(Travis::NightlyBuilder.config.gcs.creds_json)
      rescue
        JSON.load(ENV.fetch('TRAVIS_GCS_CRED_JSON'))
      end

      def files(parts)
        prefix = if parts.length > 1
          parts.insert(1, 'binaries').compact.join("/")
        else
          parts.first
        end

        if json_data = redis.get("#{prefix}:files")
          JSON.load(json_data)
        else
          gcs_viewer.bucket('travis-ci-language-archives')
          .files(prefix: prefix)
          .all
          .select {|x| x.name.end_with?('.bz2')}
          .map do |x|
            lang, _, os, release, arch, file_name = x.name.split('/')
            { 'lang' => lang, 'os' => os, 'release' => release, 'arch' => arch, 'name' => file_name }
          end.tap do |x|
            redis.set "#{prefix}:files", x.to_json, ex: 60*60*2 # 2 hours
          end
        end
      end

      def user_token_for(login)
        redis.get "user_token:#{login}"
      end

      helpers do
        def current_user
          @current_user ||= OpenStruct.new(login: session['user_login'])
        end
      end
    end
  end
end
