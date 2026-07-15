require "test_helper"

class UserAssetPerformanceTest < ActiveSupport::TestCase
  setup do
    @asset = users(:one).user_assets.create!(
      item_name: "Shares", purchase_price_cents: 1_000_000, purchase_price_currency: "AUD",
      purchase_date: Date.new(2025, 1, 10), depreciation_method: "none"
    )
  end

  test "without valuations the value is the cost basis" do
    assert_equal 1_000_000, @asset.current_value_cents

    @asset.asset_contributions.create!(occurred_on: Date.new(2025, 6, 1), amount_cents: 200_000)
    assert_equal 1_200_000, @asset.current_value_cents
    assert_equal 1_200_000, @asset.cost_basis_cents
    assert_equal 0, @asset.gain_cents
  end

  test "latest valuation drives current value" do
    @asset.asset_valuations.create!(valued_on: Date.new(2025, 6, 1), value_cents: 1_100_000)
    @asset.asset_valuations.create!(valued_on: Date.new(2025, 9, 1), value_cents: 1_250_000)

    assert_equal 1_250_000, @asset.reload.current_value_cents
    assert_equal 250_000, @asset.gain_cents
  end

  test "contributions after the last mark hold face value" do
    @asset.asset_valuations.create!(valued_on: Date.new(2025, 6, 1), value_cents: 1_100_000)
    @asset.asset_contributions.create!(occurred_on: Date.new(2025, 8, 1), amount_cents: 300_000)

    assert_equal 1_400_000, @asset.reload.current_value_cents
    assert_equal 1_300_000, @asset.cost_basis_cents
    assert_equal 100_000, @asset.gain_cents
  end

  test "value_at reflects history, not just today" do
    @asset.asset_valuations.create!(valued_on: Date.new(2025, 6, 1), value_cents: 1_100_000)
    @asset.asset_valuations.create!(valued_on: Date.new(2025, 9, 1), value_cents: 900_000)
    @asset.reload

    assert_equal 1_000_000, @asset.value_at(Date.new(2025, 3, 1))
    assert_equal 1_100_000, @asset.value_at(Date.new(2025, 7, 1))
    assert_equal 900_000, @asset.value_at(Date.new(2025, 10, 1))
    assert_equal 0, @asset.value_at(Date.new(2024, 12, 31))
  end

  test "money weighted return reflects gains" do
    travel_to Date.new(2026, 1, 10) do
      @asset.asset_valuations.create!(valued_on: Date.today, value_cents: 1_150_000)
      rate = @asset.reload.money_weighted_return

      assert_in_delta 0.15, rate, 0.01
    end
  end

  test "depreciating assets are untouched by the new logic" do
    car = users(:one).user_assets.create!(
      item_name: "Car", purchase_price_cents: 2_000_000, purchase_price_currency: "AUD",
      purchase_date: Date.today - 2.years, depreciation_method: "straight_line", useful_life_years: 10
    )

    assert_not car.market_asset?
    assert_operator car.current_value_cents, :<, 2_000_000
    assert_nil car.money_weighted_return
  end
end
