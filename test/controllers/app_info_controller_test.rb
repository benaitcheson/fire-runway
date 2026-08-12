require "test_helper"

class AppInfoControllerTest < ActionDispatch::IntegrationTest
  test "requires sign in" do
    get app_info_url
    assert_redirected_to login_url
  end

  test "shows build details to a signed in user" do
    sign_in_as users(:one)
    get app_info_url
    assert_response :success
    assert_match Rails.version, response.body
    assert_match "Git revision", response.body
  end

  test "serves the details as json" do
    sign_in_as users(:one)
    get app_info_url(format: :json)
    assert_response :success
    details = JSON.parse(response.body)
    assert_equal Rails.version, details["Rails version"]
    assert details.key?("Git revision")
  end
end
