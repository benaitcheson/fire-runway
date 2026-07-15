ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Rate limit counters live in the cache; reset them so the suite's many
    # logins don't trip the limiter across tests.
    setup { Rails.cache.clear }

    # Add more helper methods to be used by all tests here...
  end
end

module ActionDispatch
  class IntegrationTest
    def sign_in_as(user, password: "password123")
      post login_path, params: { user: { email: user.email, password: password } }
    end
  end
end
