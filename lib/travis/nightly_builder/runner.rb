require 'faraday'
require 'faraday_middleware'

module Travis
  module NightlyBuilder
    class Runner
      attr_reader :api_endpoint, :token, :owner

      def initialize(api_endpoint: ENV['TRAVIS_API_ENDPOINT'],
                     token: ENV['TRAVIS_TOKEN'],
                     owner: ENV.fetch('REPO_OWNER', 'travis-ci'))
        @api_endpoint = api_endpoint
        @token = token
        @owner = owner
      end

      def run(repo: '', branch: 'default', env: [], source: 'rake', override: {})
        conn = build_conn

        message = "build branch=#{branch}; " \
          "source=#{source}%s #{Time.now.utc.strftime('%Y%m%dT%H%M%SZ')}"
        config = {}

        if env.nil? || env.empty?
          message = format(message, nil)
        else
          config = {
            'env' => {
              'global' => env
            }
          }.merge(build_config_payload( repo: repo, branch: branch, filter: override ))

          message = format(message, "; env=#{env.inspect}")
        end

        response = conn.post do |req|
          req.url "/repo/#{owner}%2F#{repo}/requests"
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

        # pass through to the caller
        return response unless response.success?

        request_obj = JSON.load response.body
        repo_id = request_obj['repository']['id']
        request_id = request_obj['request']['id']

        Timeout::timeout(30) do
          until request_obj.fetch("@type") != 'pending'
            sleep 1
            response = conn.get do |req|
              req.url "/repo/#{repo_id}/request/#{request_id}"
              req.headers['Content-Type'] = 'application/json'
              req.headers['Travis-API-Version'] = '3'
              req.headers['Authorization'] = "token #{token}"
            end

            request_obj = JSON.load response.body
          end

          # our build request is no longer 'pending'
          return response
        end
      end

      def build_config_payload(repo:, branch: , filter: {})
        return {} if filter.empty?

        cfg = YAML.load travis_yml(repo: repo, branch: branch)

        return {} unless cfg.key?('jobs') && cfg['jobs'].key?('include')

        filtered = cfg['jobs']['include'].select do |job|
          job.values_at(*filter.keys) == filter.values
        end

        return {} if filtered.empty?

        { 'jobs' => { 'include' => filtered } }
      end

      private

      def build_conn
        Faraday.new(url: api_endpoint) do |faraday|
          faraday.request :url_encoded
          faraday.response :logger
          faraday.adapter Faraday.default_adapter
        end
      end

      def travis_yml(repo:, branch: 'default')
        # fetch `.travis.yml` from the repo's branch
        conn = Faraday.new(url: 'https://raw.githubusercontent.com') do |f|
          f.use FaradayMiddleware::FollowRedirects, limit: 5
          f.use Faraday::Request::Authorization, 'Token', ENV['GITHUB_TOKEN'] if ENV['GITHUB_TOKEN']
          f.adapter Faraday.default_adapter
        end

        response = conn.get "travis-ci/#{repo}/#{branch}/.travis.yml"

        unless response.success?
          logger.info "response=#{response.status}"
          return
        end

        response.body
      end
    end
  end
end
