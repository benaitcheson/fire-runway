require "test_helper"

module NetWorth
  class ProjectionTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      @user.user_assets.destroy_all
      @user.user_liabilities.destroy_all
    end

    def fund(cents)
      @user.user_assets.create!(item_name: "Index fund", purchase_price_cents: cents,
                                purchase_price_currency: "AUD", purchase_date: Date.today)
    end

    def project(**overrides)
      Projection.new(**{ assets: @user.user_assets.reload.to_a,
                         liabilities: @user.user_liabilities.reload.to_a,
                         current_age: 30, retirement_age: 65, horizon_years: 40,
                         annual_growth_pct: 0.0 }.merge(overrides)).call
    end

    test "produces a row per month with ages ticking over" do
      fund(100_000)
      result = project(horizon_years: 2)

      assert_equal 25, result.rows.size
      assert_equal 30, result.rows.first.age
      assert_equal 32, result.rows.last.age
      assert_equal 3, result.yearly.size
    end

    test "contributions accumulate while working with no growth" do
      fund(100_000)
      result = project(horizon_years: 1, monthly_contribution_cents: 10_000)

      assert_equal 220_000, result.final.investments_cents
      assert_equal 220_000, result.final.net_worth_cents
    end

    test "growth compounds at the real rate" do
      fund(100_000_00)
      result = project(horizon_years: 1, annual_growth_pct: 7.0, inflation_pct: 7.0)
      assert_in_delta 100_000_00, result.final.investments_cents, 12

      result = project(horizon_years: 1, annual_growth_pct: 7.0)
      assert_in_delta 107_000_00, result.final.investments_cents, 12
    end

    test "spending draws the pool down after retirement and reports when it runs dry" do
      fund(1_200_000)
      result = project(current_age: 60, retirement_age: 61, horizon_years: 5,
                       retirement_spend_cents: 100_000)

      assert_equal 1_200_000, result.at_retirement.investments_cents
      assert_equal 61, result.at_retirement.age
      assert result.depleted?
      assert_equal 62, result.depleted_at_age
      assert_equal 0, result.final.investments_cents
    end

    test "is not depleted when the pool outlasts the horizon" do
      fund(100_000_000)
      result = project(current_age: 60, retirement_age: 61, horizon_years: 10,
                       retirement_spend_cents: 100_000)

      assert_not result.depleted?
      assert_nil result.depleted_at_age
    end

    test "debts amortise at their minimum repayment and free the money when cleared" do
      @user.user_liabilities.create!(item_name: "Car loan", amount_cents: 120_000,
                                     amount_currency: "AUD", interest_rate: 0,
                                     minimum_monthly_payment_cents: 10_000)
      result = project(horizon_years: 2)

      assert_equal 120_000, result.rows.first.liabilities_cents
      assert_equal(-120_000, result.rows.first.net_worth_cents)
      assert_equal 0, result.rows[12].liabilities_cents
      assert_equal 31, result.debt_free_at_age
      # The freed $100/month is invested for the second year.
      assert_equal 120_000, result.final.investments_cents
    end

    test "a debt with no minimum repayment is held flat" do
      @user.user_liabilities.create!(item_name: "Family loan", amount_cents: 50_000,
                                     amount_currency: "AUD", interest_rate: 10)
      result = project(horizon_years: 3)

      assert_equal 50_000, result.final.liabilities_cents
      assert_nil result.debt_free_at_age
    end

    test "depreciating assets follow their curve and are never spent" do
      @user.user_assets.create!(item_name: "Car", purchase_price_cents: 3_000_000,
                                purchase_price_currency: "AUD", purchase_date: Date.today,
                                depreciation_method: "straight_line", useful_life_years: 10,
                                salvage_value_cents: 500_000)
      result = project(current_age: 60, retirement_age: 60, horizon_years: 12,
                       retirement_spend_cents: 100_000)

      assert_equal 3_000_000, result.rows.first.other_assets_cents
      assert_in_delta 500_000, result.final.other_assets_cents, 1_000
      assert_equal 0, result.final.investments_cents
    end

    test "earliest retirement age is the first that never runs dry" do
      fund(61_000_000)
      inputs = { assets: @user.user_assets.reload.to_a, liabilities: [], current_age: 30,
                 horizon_years: 40, annual_growth_pct: 0.0, monthly_contribution_cents: 100_000,
                 retirement_spend_cents: 200_000 }

      age = Projection.earliest_retirement_age(**inputs)
      # $610k + $1k/mo in until r, $2k/mo out until 70: needs (r - 30) * 12k + 610k >= (70 - r) * 24k
      assert_equal 40, age
      assert_not Projection.new(retirement_age: age, **inputs).call.depleted?
      assert Projection.new(retirement_age: age - 1, **inputs).call.depleted?
    end

    test "earliest retirement age is nil when nothing gets there" do
      fund(1_000)
      age = Projection.earliest_retirement_age(assets: @user.user_assets.reload.to_a, liabilities: [],
                                               current_age: 30, horizon_years: 10,
                                               annual_growth_pct: 0.0, retirement_spend_cents: 500_000)
      assert_nil age
    end
  end
end
