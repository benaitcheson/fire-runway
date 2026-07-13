require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: ENV["CI"] ? :headless_chrome : :chrome, screen_size: [1400, 1400] do |options|
    # Chrome's password manager and breached-password leak detection show
    # native modals (e.g. for "password123") that swallow all synthetic
    # input, intermittently killing tests. Disable them entirely.
    options.add_preference(:credentials_enable_service, false)
    options.add_preference("profile.password_manager_enabled", false)
    options.add_preference("profile.password_manager_leak_detection", false)
    options.add_argument("--disable-features=PasswordLeakDetection,PasswordManagerOnboarding")
  end
end
