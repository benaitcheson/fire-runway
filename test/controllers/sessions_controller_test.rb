require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "should get login page" do
    get login_url
    assert_response :success
  end

  test "logs in with valid credentials" do
    sign_in_as users(:one)
    assert_redirected_to dashboard_path
  end

  test "rejects invalid password" do
    post login_url, params: { user: { email: users(:one).email, password: "wrong-password" } }
    assert_response :unprocessable_entity
  end

  test "rejects unknown email" do
    post login_url, params: { user: { email: "nobody@example.com", password: "password123" } }
    assert_response :unprocessable_entity
  end

  test "logs out" do
    sign_in_as users(:one)
    delete logout_url
    get dashboard_url
    assert_redirected_to login_path
  end
end
