require "test_helper"

class AssetPerformance::XirrTest < ActiveSupport::TestCase
  test "doubling in exactly one year is ~100 percent" do
    rate = AssetPerformance::Xirr.new([
      [Date.new(2025, 1, 1), -100_000],
      [Date.new(2026, 1, 1), 200_000]
    ]).call

    assert_in_delta 1.0, rate, 0.01
  end

  test "flat value is ~0 percent" do
    rate = AssetPerformance::Xirr.new([
      [Date.new(2025, 1, 1), -100_000],
      [Date.new(2026, 1, 1), 100_000]
    ]).call

    assert_in_delta 0.0, rate, 0.005
  end

  test "a later contribution is weighted by its time in the market" do
    # $1,000 for a year and $1,000 for one day, worth $2,100 total:
    # nearly all the gain belongs to the early money.
    rate = AssetPerformance::Xirr.new([
      [Date.new(2025, 1, 1), -100_000],
      [Date.new(2025, 12, 31), -100_000],
      [Date.new(2026, 1, 1), 210_000]
    ]).call

    assert_operator rate, :>, 0.08
    assert_operator rate, :<, 0.12
  end

  test "losses come back negative" do
    rate = AssetPerformance::Xirr.new([
      [Date.new(2025, 1, 1), -100_000],
      [Date.new(2026, 1, 1), 50_000]
    ]).call

    assert_operator rate, :<, -0.4
  end

  test "nil for a span too short to annualise" do
    rate = AssetPerformance::Xirr.new([
      [Date.today - 5, -100_000],
      [Date.today, 101_000]
    ]).call

    assert_nil rate
  end

  test "nil when flows are all one direction" do
    assert_nil AssetPerformance::Xirr.new([[Date.new(2025, 1, 1), -100], [Date.new(2026, 1, 1), -100]]).call
    assert_nil AssetPerformance::Xirr.new([[Date.new(2025, 1, 1), 100]]).call
  end
end
