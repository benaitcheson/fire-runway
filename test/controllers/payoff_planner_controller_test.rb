require "test_helper"

class PayoffPlannerControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "shows empty state without liabilities" do
    @user.user_liabilities.destroy_all
    get payoff_planner_url
    assert_response :success
    assert_match "Add your debts first", response.body
  end

  test "recommends the highest rate debt first" do
    @user.user_liabilities.destroy_all
    @user.user_liabilities.create!(item_name: "Credit card", amount_cents: 300_000,
                                   amount_currency: "AUD", interest_rate: 20.0)
    @user.user_liabilities.create!(item_name: "Car loan", amount_cents: 1_000_000,
                                   amount_currency: "AUD", interest_rate: 8.0)

    get payoff_planner_url, params: { monthly_budget: 800 }
    assert_response :success
    assert_match "Pay off Credit card first", response.body
    assert_match "Snowball", response.body
  end

  test "defaults spare cash to the budget surplus" do
    @user.budget_items.create!(section: "income", name: "Salary", amount_cents: 500_000, frequency: "monthly")
    @user.budget_items.create!(section: "bills", name: "Rent", amount_cents: 200_000, frequency: "monthly")

    get payoff_planner_url
    assert_response :success
    assert_match 'value="3000"', response.body
  end

  test "warns when the budget cannot cover interest" do
    @user.user_liabilities.destroy_all
    @user.user_liabilities.create!(item_name: "Loan shark", amount_cents: 5_000_000,
                                   amount_currency: "AUD", interest_rate: 50.0)

    get payoff_planner_url, params: { monthly_budget: 10 }
    assert_response :success
    assert_match "doesn't cover the interest", response.body
  end

  test "requires login" do
    delete logout_url
    get payoff_planner_url
    assert_redirected_to login_path
  end
end
