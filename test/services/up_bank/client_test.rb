require "test_helper"

module UpBank
  class ClientTest < ActiveSupport::TestCase
    test "raises ConfigurationError without a token" do
      assert_raises(ConfigurationError) do
        Client.new(token: nil).transactions(since: Time.current)
      end
    end

    test "follows pagination and filters to settled transactions" do
      requests = []
      stubs = Faraday::Adapter::Test::Stubs.new do |stub|
        stub.get("/api/v1/transactions") do |env|
          requests << Rack::Utils.parse_query(env.url.query)
          if requests.size == 1
            [200, { "Content-Type" => "application/json" },
             { "data" => [{ "id" => "t1" }],
               "links" => { "next" => "#{Client::BASE_URL}transactions?page%5Bafter%5D=cursor" } }.to_json]
          else
            [200, { "Content-Type" => "application/json" },
             { "data" => [{ "id" => "t2" }], "links" => { "next" => nil } }.to_json]
          end
        end
      end

      client = Client.new(token: "tok", connection: test_connection(stubs))
      data = client.transactions(since: Time.utc(2026, 5, 1))

      assert_equal %w[t1 t2], data.map { |t| t["id"] }
      assert_equal 2, requests.size
      assert_equal "SETTLED", requests.first["filter[status]"]
      assert_equal "2026-05-01T00:00:00Z", requests.first["filter[since]"]
      assert_equal "cursor", requests.last["page[after]"]
    end

    test "raises AuthError on 401" do
      stubs = Faraday::Adapter::Test::Stubs.new do |stub|
        stub.get("/api/v1/transactions") { [401, {}, ""] }
      end

      assert_raises(AuthError) do
        Client.new(token: "bad", connection: test_connection(stubs)).transactions(since: Time.current)
      end
    end

    private

    def test_connection(stubs)
      Faraday.new(url: Client::BASE_URL) do |f|
        f.response :json
        f.adapter :test, stubs
      end
    end
  end
end
