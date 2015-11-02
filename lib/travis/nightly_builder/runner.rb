require 'faraday'

module Travis
  module NightlyBuilder
    class Runner
      attr_reader :api_endpoint, :token

      def initialize(api_endpoint: ENV['TRAVIS_API_ENDPOINT'],
                     token: ENV['TRAVIS_TOKEN'])
        @api_endpoint = api_endpoint
        @token = token
      end

      def run(repo: '', branch: 'default', env: [])
        conn = Faraday.new(url: api_endpoint) do |faraday|
          faraday.request :url_encoded
          faraday.response :logger
          faraday.adapter Faraday.default_adapter
        end

        message = "Build repo=#{repo}; branch=#{branch}%s " \
          "#{Time.now.utc.strftime('%Y-%m-%d-%H-%M-%S')}"
        config = {}

        if env.empty?
          message = format(message, nil)
        else
          config = {
            'env' => {
              'global' => env
            }
          }

          message = format(message, "; (#{env})")
        end

        conn.post do |req|
          req.url "/repo/travis-ci%2F#{repo}/requests"
          req.headers['Content-Type'] = 'application/json'
          req.headers['Travis-API-Version'] = '3'
          req.headers['Authorization'] = "token #{token}"
          req.body = {
            request: {
              message: message,
              branch: branch,
              config: config
            }
          }.to_json
        end
      end
    end
  end
end
