require "test_helper"

class ForecastControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "requires sign in" do
    delete logout_url
    get forecast_url
    assert_redirected_to login_url
  end

  test "renders with defaults" do
    get forecast_url
    assert_response :success
    assert_match 'value="30"', response.body
    assert_match 'value="65"', response.body
    assert_match 'value="40"', response.body
    assert_match "Milestones", response.body
    assert_match "Net worth, year by year", response.body
  end

  test "remembers recalculated inputs and reopens with them" do
    get forecast_url, params: { current_age: 34, retirement_age: 55, horizon_years: 45,
                                annual_growth: 6.5, inflation: 3, monthly_contribution: 1500.5,
                                retirement_spend: 4200 }
    assert_response :success
    @user.reload
    assert_equal Date.today.year - 34, @user.forecast_birth_year
    assert_equal 55, @user.forecast_retirement_age
    assert_equal 45, @user.forecast_horizon_years
    assert_equal 6.5, @user.forecast_annual_growth.to_f
    assert_equal 3.0, @user.forecast_inflation.to_f
    assert_equal 150_050, @user.forecast_monthly_contribution_cents
    assert_equal 420_000, @user.forecast_retirement_spend_cents

    get forecast_url
    assert_response :success
    assert_match 'value="34"', response.body
    assert_match 'value="55"', response.body
    assert_match 'value="1500.5"', response.body
    assert_match 'value="4200"', response.body
  end

  test "defaults contribution and spend from the budget" do
    @user.budget_items.destroy_all
    @user.budget_items.create!(section: "income", name: "Salary", amount_cents: 500_000, frequency: "monthly")
    @user.budget_items.create!(section: "bills", name: "Rent", amount_cents: 200_000, frequency: "monthly")
    @user.budget_items.create!(section: "everyday", name: "Food", amount_cents: 100_000, frequency: "monthly")

    get forecast_url
    assert_response :success
    assert_match(/value="2000"[^>]*name="monthly_contribution"/, response.body)
    assert_match(/value="3000"[^>]*name="retirement_spend"/, response.body)
  end

  test "says when the money runs out and when you could retire instead" do
    @user.user_liabilities.destroy_all
    @user.user_assets.destroy_all
    @user.user_assets.create!(item_name: "Index fund", purchase_price_cents: 10_000_000,
                              purchase_price_currency: "AUD", purchase_date: Date.today)

    get forecast_url, params: { current_age: 40, retirement_age: 45, horizon_years: 40,
                                annual_growth: 0, inflation: 0, monthly_contribution: 2000,
                                retirement_spend: 3000 }
    assert_response :success
    assert_match "Your investments run out at age", response.body
    assert_match "Retiring at <strong>", response.body
  end

  test "celebrates when the money lasts" do
    @user.user_liabilities.destroy_all
    @user.user_assets.destroy_all
    @user.user_assets.create!(item_name: "Index fund", purchase_price_cents: 200_000_000,
                              purchase_price_currency: "AUD", purchase_date: Date.today)

    get forecast_url, params: { current_age: 40, retirement_age: 50, horizon_years: 40,
                                annual_growth: 5, inflation: 2.5, retirement_spend: 4000 }
    assert_response :success
    assert_match "Your money lasts to age 80", response.body
  end

  test "clamps a silly horizon" do
    get forecast_url, params: { current_age: 30, horizon_years: 500 }
    assert_response :success
    assert_equal NetWorth::Projection::MAX_YEARS, @user.reload.forecast_horizon_years
  end
end
