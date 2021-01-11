require 'faraday'
require 'faraday_middleware'
require 'timeout'
require 'travis/logger'

module Travis
  module NightlyBuilder
    class Runner
      attr_reader :api_endpoint, :owner

      def initialize(api_endpoint: ENV['TRAVIS_API_ENDPOINT'],
                     owner: ENV.fetch('REPO_OWNER', 'travis-ci'))
        @api_endpoint = api_endpoint
        @owner = owner
      end

      def run(repo: '', token: ENV['TRAVIS_TOKEN'], branch: 'default', env: [], source: 'rake', override: {})
        conn = build_conn

        message = "build branch=#{branch}; " \
          "source=#{source}%s #{Time.now.utc.strftime('%Y%m%dT%H%M%SZ')}"
        config = {}

        if env.nil? || env.empty?
          message = format(message, nil)
        else
          config = {
            "merge_mode" => "deep_merge",
            'env' => {
              'global' => env
            },
          }.merge(build_config_payload( repo: repo, branch: branch, filter: override ))

          logger.debug "config=#{config}"

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
          }.to_json.tap {|x| logger.debug "body=#{x}"}
        end

        # pass through to the caller
        return response unless response.success?

        request_obj = JSON.load response.body
        repo_id = request_obj['repository']['id']
        request_id = request_obj['request']['id']

        Timeout::timeout(30) do
          until request_obj.fetch("@type") == 'request' &&
              !request_obj["builds"].empty?
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

      rescue Timeout::Error => e
        return Faraday::Response.new # return empty response
      end

      def build_config_payload(repo:, branch: , filter: {})
        return {} if filter.empty?

        filter = refine(filter)

        cfg = YAML.load travis_yml(repo: repo, branch: branch)
        logger.debug "cfg=#{cfg}"
        logger.debug "filter=#{filter}"

        return {} unless cfg.key?('jobs') && cfg['jobs'].key?('include')

        filtered = cfg['jobs']['include'].select do |job|
          set_defaults(job).values_at(*filter.keys) == filter.values
        end

        logger.debug "filtered=#{filtered}"

        return {} if filtered.empty?

        { 'jobs' => { 'include' => filtered } }.tap {|x| logger.debug "filtered_config=#{x}"}
      end

      private

      def logger
        @logger ||= Travis::Logger.new(STDOUT)
        @logger.level = Logger.const_get(ENV.fetch("LOG_LEVEL", "INFO").upcase)
        @logger
      end

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

        response = conn.get "#{owner}/#{repo}/#{branch}/.travis.yml"

        unless response.success?
          logger.debug "response=#{response.status}"
          return '{}'
        end

        response.body
      end

      def set_defaults(job)
        job['os'] ||= 'linux'
        if job['os'] == 'linux'
          job['dist'] ||= 'xenial'
          job['arch'] ||= 'x86_64'
        end
        if job['os'] == 'osx'
          job['osx_image'] ||= 'xcode9.4'
        end
        job
      end

      def refine(filter)
        case filter["os"]
        when 'linux', 'freebsd'
          filter.delete 'osx_image'
        when 'osx'
          filter.delete 'dist'
        end

        filter
      end
    end
  end
end
