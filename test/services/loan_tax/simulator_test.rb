require "test_helper"

module LoanTax
  class SimulatorTest < ActiveSupport::TestCase
    def simulate(**overrides)
      defaults = {
        gross_salary: 120_000, loan_amount: 100_000, interest_rate_pct: 10.0,
        loan_type: "principal_and_interest", term_years: 10,
        dividend_yield_pct: 0.0, franking_pct: 100.0, capital_growth_pct: 0.0
      }
      Simulator.new(**defaults.merge(overrides)).call
    end

    test "returns nil for a zero loan or term" do
      assert_nil simulate(loan_amount: 0)
      assert_nil simulate(term_years: 0)
    end

    test "P&I interest declines each year and the loan ends at zero" do
      result = simulate
      interests = result.years.map(&:interest)
      assert_equal interests.sort.reverse, interests
      assert interests.first > interests.last
      assert_in_delta 0.0, result.years.last.closing_balance, 0.01
    end

    test "interest-only keeps interest and balance constant" do
      result = simulate(loan_type: "interest_only")
      assert result.years.map(&:interest).uniq.map { |i| i.round(2) }.one?
      assert_in_delta 10_000, result.years.first.interest, 0.01
      assert_in_delta 100_000, result.years.last.closing_balance, 0.01
      assert result.verdict.interest_only
    end

    test "zero-yield tax saved is the composite marginal rate on the interest" do
      # $120k salary sits in the 30% bracket + 2% Medicare; MLS and HECS are
      # held up by the loss add-back, so only 32% of the interest comes back.
      result = simulate(loan_type: "interest_only")
      assert_in_delta 10_000 * 0.32, result.year_one.tax_saved, 0.01
    end

    test "negative gearing does not touch HECS (the gotcha)" do
      result = simulate(loan_type: "interest_only", has_hecs: true)
      row = result.years.first
      assert_equal :negative, result.year_one.gearing_position
      assert_in_delta row.hecs_without, row.hecs_with, 0.01
      assert result.year_one.tax_saved.positive?
    end

    test "MLS is held up by the add-back too" do
      result = simulate(loan_type: "interest_only")
      with_loan = result.year_one.with_loan
      assert_equal 120_000, with_loan.surcharge_income
      assert_in_delta 1_500, with_loan.medicare_levy_surcharge, 0.01
    end

    test "franking credits gross up dividends" do
      result = simulate(dividend_yield_pct: 7.0, franking_pct: 100.0)
      row = result.years.first
      assert_in_delta 7_000, row.dividends, 0.01
      assert_in_delta 3_000, row.franking_credits, 0.01
    end

    test "positive gearing raises tax instead of saving it" do
      result = simulate(loan_type: "interest_only", interest_rate_pct: 2.0,
                        dividend_yield_pct: 7.0, franking_pct: 0.0)
      assert_equal :positive, result.year_one.gearing_position
      assert result.year_one.tax_saved.negative?
    end

    test "verdict break-even flips with assumed growth" do
      behind = simulate(loan_type: "interest_only", capital_growth_pct: 0.0)
      ahead = simulate(loan_type: "interest_only", capital_growth_pct: 12.0)
      assert_not behind.verdict.break_even
      assert ahead.verdict.break_even
    end

    test "after-tax cost of debt reflects the deduction" do
      result = simulate(loan_type: "interest_only")
      assert_in_delta 6.8, result.verdict.after_tax_cost_of_debt_pct, 0.01
    end

    test "HECS balance runs down separately on both sides" do
      result = simulate(gross_salary: 100_000, loan_type: "interest_only",
                        has_hecs: true, hecs_balance: 5_000)
      # $100k income repays $4,950/yr, so the balance caps year 2 at $50.
      assert_in_delta 4_950, result.years.first.hecs_without, 0.01
      assert_in_delta 50, result.years.second.hecs_without, 0.01
      assert_equal 0.0, result.years.third.hecs_without
    end
  end
end
