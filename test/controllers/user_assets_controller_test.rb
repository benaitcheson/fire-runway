require "test_helper"

class UserAssetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @asset = user_assets(:one)
    sign_in_as @user
  end

  test "should get index" do
    get user_assets_url
    assert_response :success
  end

  test "should get show" do
    get user_asset_url(@asset)
    assert_response :success
  end

  test "should get new" do
    get new_user_asset_url
    assert_response :success
  end

  test "should create asset" do
    assert_difference("@user.user_assets.count") do
      post user_assets_url, params: { user_asset: {
        item_name: "Bike", purchase_price_cents: 50_000,
        purchase_price_currency: "AUD", purchase_date: Date.new(2024, 1, 1)
      } }
    end
    assert_redirected_to user_asset_url(@user.user_assets.order(:id).last)
  end

  test "should get edit" do
    get edit_user_asset_url(@asset)
    assert_response :success
  end

  test "should update asset" do
    patch user_asset_url(@asset), params: { user_asset: { item_name: "Renamed" } }
    assert_redirected_to user_asset_url(@asset)
    assert_equal "Renamed", @asset.reload.item_name
  end

  test "should destroy asset" do
    assert_difference("@user.user_assets.count", -1) do
      delete user_asset_url(@asset)
    end
    assert_redirected_to user_assets_url
  end

  test "cannot access another user's asset" do
    get user_asset_url(user_assets(:two))
    assert_response :not_found
  end

  test "redirects to login when signed out" do
    delete logout_path
    get user_assets_url
    assert_redirected_to login_path
  end
end
