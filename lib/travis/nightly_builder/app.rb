require 'json'
require 'sinatra/base'
require 'sinatra/param'
require 'sinatra/contrib'
require 'google/cloud/storage'
require 'ostruct'

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

        types = %w[text/html application/json]

        if request.preferred_type(types) == 'application/json'
          archives.map(&:to_h).to_json
        else
          slim :index
        end
      end

      post '/build' do
        param :branch, String, default: 'default'
        param :env, Array, default: []
        param :source, String, default: ENV['DYNO']

        overridable = %w(os dist arch)

        form_data = params.select {|k, v| overridable.include?(k) && !v.to_s.empty?}
        env = [params['env'], "VERSION=#{params['version']}"].reject(&:empty?).compact.join(" ")

        results = runner.run(
          repo: params['repo'],
          branch: params['branch'],
          env: env,
          source: params['source'],
          override: form_data
        )

        halt 400 unless results.success?

        build = JSON.parse(results.body).fetch('builds').first

        redirect "https://travis-ci.com/travis-ci/#{params['repo']}/builds/#{build['id']}"
      end

      run! if app_file == $PROGRAM_NAME

      private

      def runner
        @runner ||= Runner.new(
          api_endpoint: ENV.fetch('TRAVIS_API_ENDPOINT'),
          token: ENV.fetch('TRAVIS_TOKEN')
        )
      end

      def gcs_viewer
        @viewer ||= Google::Cloud::Storage.new(
          project_id: ENV.fetch('TRAVIS_GCS_PROJECT_ID'),
          credentials: gcs_read_creds
        )
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

        gcs_viewer.bucket('travis-ci-language-archives')
        .files(prefix: prefix)
        .all
        .select {|x| x.name.end_with?('.bz2')}
        .map do |x|
          lang, _, os, release, arch, file_name = x.name.split('/')
          OpenStruct.new(lang: lang, os: os, release: release, arch: arch, name: file_name)
        end
      end

    end
  end
end
