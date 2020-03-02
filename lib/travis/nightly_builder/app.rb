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
      class << self
        def auth_tokens
          @auth_tokens ||= (ENV['AUTH_TOKENS'] || '').split(':').map(&:strip)
        end

        def base_env
          @base_env ||= Hash[ENV]
        end
      end

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
          whitelisted?: -> r { r.path == '/hello' || ( r.get? && UNAUTHENTICATED_CONTENT_TYPES.include?(r.get_header("HTTP_ACCEPT"))) },
          set_user: -> r, u {
            p "session=#{r.session.to_hash}"
            p "u=#{u.inspect}"
            r.session['user_login'] = u['login']
          },
          user_id_key: 'user_login',
          endpoint: 'https://api.travis-ci.com'
        # include Travis::SSO::Helpers
        register Travis::SSO
      end

      helpers Sinatra::Param

      attr_reader :archives

      get '/hello' do
        "ohai\n"
      end

      before do
        logger.debug "session=#{session.to_hash}"
      end

      before '/builds/*' do
        logger.debug "current_user=#{current_user.login}" if current_user
        logger.debug "request=#{request}"
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
          token: current_user['token'],
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

      helpers do
        def current_user
          @current_user ||= OpenStruct.new(login: session['user_login'])
        end
      end
    end
  end
end
