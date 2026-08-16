# Namespace and error hierarchy for the Up Bank integration.
module UpBank
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class AuthError < Error; end
  class ApiError < Error; end
end
