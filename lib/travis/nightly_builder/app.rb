require 'json'
require 'sinatra/base'
require 'sinatra/param'
require 'sinatra/contrib'

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

      get '/hello' do
        "ohai\n"
      end

      post '/build/:repo' do
        param :branch, String, default: 'default'
        param :env, Array, default: []

        results = runner.run(
          repo: params['repo'],
          branch: params['branch'],
          env: params['env']
        )

        halt 400 unless results.success?

        status 201
        json data: results.map { |r| JSON.parse(r.body) }
      end

      run! if app_file == $PROGRAM_NAME

      private

      def runner
        @runner ||= Runner.new(
          api_endpoint: ENV.fetch('TRAVIS_API_ENDPOINT'),
          token: ENV.fetch('TRAVIS_TOKEN')
        )
      end
    end
  end
end
