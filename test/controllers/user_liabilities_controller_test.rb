require "test_helper"

class UserLiabilitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @liability = user_liabilities(:one)
    sign_in_as @user
  end

  test "should get index" do
    get user_liabilities_url
    assert_response :success
  end

  test "should get show" do
    get user_liability_url(@liability)
    assert_response :success
  end

  test "should get new" do
    get new_user_liability_url
    assert_response :success
  end

  test "should create liability" do
    assert_difference("@user.user_liabilities.count") do
      post user_liabilities_url, params: { user_liability: {
        item_name: "Car loan", amount_cents: 1_000_000, amount_currency: "AUD"
      } }
    end
  end

  test "should get edit" do
    get edit_user_liability_url(@liability)
    assert_response :success
  end

  test "should update liability" do
    patch user_liability_url(@liability), params: { user_liability: { amount_cents: 123_456 } }
    assert_equal 123_456, @liability.reload.amount_cents
  end

  test "should destroy liability" do
    assert_difference("@user.user_liabilities.count", -1) do
      delete user_liability_url(@liability)
    end
  end

  test "redirects to login when signed out" do
    delete logout_path
    get user_liabilities_url
    assert_redirected_to login_path
  end
end
