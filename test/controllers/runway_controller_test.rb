require "test_helper"

class RunwayControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "requires sign in" do
    delete logout_url
    get runway_url
    assert_redirected_to login_url
  end

  test "prompts for a budget when there is no spend" do
    @user.budget_items.destroy_all
    get runway_url
    assert_response :success
    assert_match "Set up your budget", response.body
  end

  test "shows how long the money lasts" do
    @user.user_liabilities.destroy_all
    @user.user_assets.destroy_all
    @user.user_assets.create!(item_name: "Index fund", purchase_price_cents: 2_400_000,
                              purchase_price_currency: "AUD", purchase_date: 1.year.ago.to_date)

    get runway_url, params: { monthly_spend: 1000 }
    assert_response :success
    assert_match "Your money would last 2 years", response.body
  end

  test "defaults the spend to the budget's bills and everyday sections" do
    @user.budget_items.destroy_all
    @user.budget_items.create!(section: "bills", name: "Rent", amount_cents: 120_000, frequency: "monthly")
    @user.budget_items.create!(section: "everyday", name: "Groceries", amount_cents: 30_000, frequency: "weekly")

    get runway_url
    assert_response :success
    # $1,200 + ($300 * 52 / 12) = $2,500/month
    assert_match 'value="2500"', response.body
  end

  test "warns when liabilities swallow the assets" do
    @user.user_assets.destroy_all
    get runway_url, params: { monthly_spend: 1000 }
    assert_response :success
    assert_match "No runway yet", response.body
  end

  test "reports an indefinite runway when growth covers spending" do
    @user.user_liabilities.destroy_all
    @user.user_assets.destroy_all
    @user.user_assets.create!(item_name: "Index fund", purchase_price_cents: 100_000_000,
                              purchase_price_currency: "AUD", purchase_date: 1.year.ago.to_date)

    get runway_url, params: { monthly_spend: 2000, annual_growth: 4.0 }
    assert_response :success
    assert_match "outlasts the horizon", response.body
  end
end
