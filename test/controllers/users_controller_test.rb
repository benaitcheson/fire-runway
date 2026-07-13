require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "should get sign up page" do
    get sign_up_url
    assert_response :success
  end

  test "creates a user with valid details" do
    assert_difference("User.count") do
      post sign_up_url, params: { user: {
        email: "new@example.com", password: "password123", password_confirmation: "password123"
      } }
    end
    assert_redirected_to root_path
  end

  test "rejects mismatched password confirmation" do
    assert_no_difference("User.count") do
      post sign_up_url, params: { user: {
        email: "new@example.com", password: "password123", password_confirmation: "different"
      } }
    end
    assert_response :unprocessable_entity
  end
end
