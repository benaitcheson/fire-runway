require "test_helper"

module Runway
  class SimulatorTest < ActiveSupport::TestCase
    test "divides evenly with no growth" do
      result = Simulator.new(starting_pool_cents: 1_200_000, monthly_spend_cents: 100_000).call

      assert_equal 12, result.months
      assert_not result.indefinite
      assert_equal Date.today >> 12, result.depletion_date
      assert_equal "1 year", result.in_words
    end

    test "growth extends the runway" do
      without_growth = Simulator.new(starting_pool_cents: 10_000_000, monthly_spend_cents: 100_000).call
      with_growth = Simulator.new(starting_pool_cents: 10_000_000, monthly_spend_cents: 100_000,
                                  annual_growth_pct: 5.0).call

      assert with_growth.months > without_growth.months
    end

    test "is indefinite when growth covers the spend" do
      # 4% of $1m is ~$3,333/month, spend is $2,000
      result = Simulator.new(starting_pool_cents: 100_000_000, monthly_spend_cents: 200_000,
                             annual_growth_pct: 4.0).call

      assert result.indefinite
      assert_nil result.months
      assert_equal "indefinitely", result.in_words
    end

    test "empty pool has no runway" do
      result = Simulator.new(starting_pool_cents: 0, monthly_spend_cents: 100_000).call

      assert_equal 0, result.months
      assert_nil result.depletion_date
      assert_equal "no time at all", result.in_words
    end

    test "zero spend is indefinite" do
      result = Simulator.new(starting_pool_cents: 100_000, monthly_spend_cents: 0).call

      assert result.indefinite
    end

    test "monthly totals start at the pool and end at zero" do
      result = Simulator.new(starting_pool_cents: 300_000, monthly_spend_cents: 100_000).call

      assert_equal 300_000, result.monthly_totals[0]
      assert_equal 0, result.monthly_totals[result.months]
      assert_equal result.months + 1, result.monthly_totals.size
    end

    test "reads as years and months" do
      result = Simulator.new(starting_pool_cents: 1_400_000, monthly_spend_cents: 100_000).call

      assert_equal 14, result.months
      assert_equal "1 year, 2 months", result.in_words
    end
  end
end
