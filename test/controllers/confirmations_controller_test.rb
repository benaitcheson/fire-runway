require "test_helper"

class ConfirmationsControllerTest < ActionDispatch::IntegrationTest
  test "confirms a user with a valid token" do
    user = User.create!(email: "unconfirmed@example.com", password: "password123")
    get email_confirmation_url(user.generate_confirmation_token)
    assert_redirected_to root_path
    assert user.reload.confirmed?
  end
end
