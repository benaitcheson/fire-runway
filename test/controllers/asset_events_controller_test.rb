require "test_helper"

class AssetEventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @asset = @user.user_assets.create!(
      item_name: "Shares", purchase_price_cents: 1_000_000, purchase_price_currency: "AUD",
      purchase_date: Date.new(2025, 1, 1), depreciation_method: "none"
    )
    sign_in_as @user
  end

  test "records a valuation in dollars" do
    post user_asset_asset_valuations_url(@asset), params: {
      asset_valuation: { valued_on: Date.today, value: 12_500.50 }
    }
    assert_redirected_to user_asset_url(@asset)
    assert_equal 1_250_050, @asset.asset_valuations.last.value_cents
  end

  test "records a contribution and updates cost basis" do
    post user_asset_asset_contributions_url(@asset), params: {
      asset_contribution: { occurred_on: Date.today, amount: 2_000 }
    }
    assert_equal 1_200_000, @asset.reload.cost_basis_cents
  end

  test "rejects future-dated valuations with a visible error" do
    post user_asset_asset_valuations_url(@asset), params: {
      asset_valuation: { valued_on: Date.tomorrow, value: 100 }
    }
    assert_redirected_to user_asset_url(@asset)
    follow_redirect!
    assert_match "can&#39;t be in the future", response.body
  end

  test "cannot add events to another user's asset" do
    other_asset = user_assets(:two)
    post user_asset_asset_valuations_url(other_asset), params: {
      asset_valuation: { valued_on: Date.today, value: 1 }
    }
    assert_response :not_found

    post user_asset_asset_contributions_url(other_asset), params: {
      asset_contribution: { occurred_on: Date.today, amount: 1 }
    }
    assert_response :not_found
  end

  test "destroying events is scoped to the owner" do
    valuation = @asset.asset_valuations.create!(valued_on: Date.today, value_cents: 100)

    delete logout_url
    sign_in_as users(:two)
    delete user_asset_asset_valuation_url(@asset, valuation)
    assert_response :not_found
    assert AssetValuation.exists?(valuation.id)
  end
end
