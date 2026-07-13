require "test_helper"

class InvestmentComparisonControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "defaults use the user's investable assets and budget" do
    @user.user_assets.destroy_all
    @user.user_assets.create!(item_name: "Cash", purchase_price_cents: 5_000_000,
                              purchase_price_currency: "AUD", purchase_date: Date.new(2025, 1, 1),
                              depreciation_method: "none")
    @user.user_assets.create!(item_name: "Super fund", purchase_price_cents: 20_000_000,
                              purchase_price_currency: "AUD", purchase_date: Date.new(2025, 1, 1),
                              depreciation_method: "none")
    @user.budget_items.create!(section: "income", name: "Salary", amount_cents: 700_000, frequency: "monthly")
    @user.budget_items.create!(section: "bills", name: "Rent", amount_cents: 200_000, frequency: "monthly")

    get investment_comparison_url
    assert_response :success

    # $50k cash only — super excluded
    assert_match(/name="initial_capital"\s+value="50000"/m, response.body)
    # ($7,000 - $2,000) monthly surplus
    assert_match(/name="monthly_savings"\s+value="5000"/m, response.body)
    # $84k net grossed up by 0.7 = $120k
    assert_match(/name="salary"\s+value="120000"/m, response.body)
  end

  test "renders with randomised fallbacks when user has no data" do
    get investment_comparison_url
    assert_response :success
  end
end
