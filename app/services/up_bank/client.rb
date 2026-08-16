module UpBank
  # Thin wrapper over the Up Bank personal API (https://developer.up.com.au).
  # Raises typed errors so callers can distinguish a bad token from an outage.
  class Client
    # Trailing slash matters: Faraday joins relative paths onto it, while a
    # leading-slash path would discard the /api/v1 prefix.
    BASE_URL = "https://api.up.com.au/api/v1/".freeze
    PAGE_SIZE = 100

    def initialize(token: ENV["UP_API_TOKEN"], connection: nil)
      @token = token
      @connection = connection
    end

    def configured?
      @token.present?
    end

    def ping
      get("util/ping")
      true
    end

    # All settled transactions since a time, newest first, across every page.
    # Returns the raw JSON:API resource hashes from "data".
    def transactions(since:, before: nil)
      params = {
        "page[size]" => PAGE_SIZE,
        "filter[status]" => "SETTLED",
        "filter[since]" => since.utc.iso8601
      }
      params["filter[until]"] = before.utc.iso8601 if before

      data = []
      body = get("transactions", params)
      loop do
        data.concat(body.fetch("data", []))
        next_url = body.dig("links", "next")
        break unless next_url

        body = get(next_url)
      end
      data
    end

    private

    def get(path, params = nil)
      raise ConfigurationError, "UP_API_TOKEN is not set" unless configured?

      response = connection.get(path, params)
      case response.status
      when 200 then response.body
      when 401 then raise AuthError, "Up rejected the API token"
      else raise ApiError, "Up returned HTTP #{response.status}"
      end
    rescue Faraday::Error => e
      raise ApiError, e.message
    end

    def connection
      @connection ||= Faraday.new(url: BASE_URL) do |f|
        f.headers["Authorization"] = "Bearer #{@token}"
        f.response :json
      end
    end
  end
end
