require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "should get index when signed in" do
    sign_in_as users(:one)
    get dashboard_url
    assert_response :success
  end

  test "root shows dashboard when signed in" do
    sign_in_as users(:one)
    get root_url
    assert_response :success
  end

  test "redirects to login when signed out" do
    get dashboard_url
    assert_redirected_to login_path
  end
end
