# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

demo = User.find_or_create_by!(email: "demo@example.com") do |user|
  user.password = "password123"
end
demo.confirm!

# Values are randomised within a plausible range per item on first creation;
# re-running the seeds leaves existing records untouched.
dollars = ->(min, max) { rand(min..max) * 100 }
date_between = ->(from, to) { rand(from..to) }

assets = [
  { item_name: "Car", purchase_price_cents: dollars.(15_000, 45_000),
    purchase_date: date_between.(Date.new(2018, 1, 1), Date.new(2023, 12, 31)),
    depreciation_method: "straight_line", useful_life_years: 10 },
  { item_name: "Laptop", purchase_price_cents: dollars.(1_500, 5_000),
    purchase_date: date_between.(Date.new(2022, 1, 1), Date.new(2025, 6, 30)),
    depreciation_method: "straight_line", useful_life_years: 5 },
  { item_name: "Motorbike", purchase_price_cents: dollars.(4_000, 15_000),
    purchase_date: date_between.(Date.new(2019, 1, 1), Date.new(2024, 12, 31)),
    depreciation_method: "declining_balance", depreciation_rate: 20.0 },
  { item_name: "Cash savings", purchase_price_cents: dollars.(5_000, 80_000),
    purchase_date: date_between.(Date.new(2024, 6, 1), Date.today),
    depreciation_method: "none" },
  { item_name: "ETF portfolio", purchase_price_cents: dollars.(10_000, 150_000),
    purchase_date: date_between.(Date.new(2024, 6, 1), Date.today),
    depreciation_method: "none" },
  { item_name: "Superannuation", purchase_price_cents: dollars.(30_000, 250_000),
    purchase_date: date_between.(Date.new(2024, 6, 1), Date.today),
    depreciation_method: "none" }
]

assets.each do |attrs|
  demo.user_assets.find_or_create_by!(item_name: attrs[:item_name]) do |asset|
    salvage = attrs[:depreciation_method] == "none" ? nil : attrs[:purchase_price_cents] / rand(8..20)
    asset.assign_attributes(purchase_price_currency: "AUD", salvage_value_cents: salvage, **attrs)
  end
end

liabilities = [
  { item_name: "HECS debt", amount_cents: dollars.(10_000, 60_000),
    interest_rate: rand(2.0..5.0).round(1), minimum_monthly_payment_cents: 0 },
  { item_name: "Credit card", amount_cents: dollars.(500, 8_000),
    interest_rate: rand(17.0..22.0).round(1), minimum_monthly_payment_cents: dollars.(25, 100) },
  { item_name: "Car loan", amount_cents: dollars.(3_000, 25_000),
    interest_rate: rand(6.0..10.0).round(1), minimum_monthly_payment_cents: dollars.(150, 400) }
]

liabilities.each do |attrs|
  liability = demo.user_liabilities.find_or_create_by!(item_name: attrs[:item_name]) do |l|
    l.assign_attributes(amount_currency: "AUD", **attrs)
  end
  # Backfill payoff fields on rows created before those columns existed.
  if liability.interest_rate.zero? && attrs[:interest_rate].positive?
    liability.update!(attrs.slice(:interest_rate, :minimum_monthly_payment_cents))
  end
end

# Give the ETF portfolio a monthly history of contributions and marks so the
# performance chart has something to show. Only runs when it has no history.
etf = demo.user_assets.find_by(item_name: "ETF portfolio")
if etf && etf.asset_valuations.none?
  value = etf.purchase_price_cents
  6.downto(1) do |months_ago|
    date = [Date.today << months_ago, etf.purchase_date + 1].max
    if months_ago.even?
      amount = rand(50..200) * 1_000
      etf.asset_contributions.find_or_create_by!(occurred_on: date, amount_cents: amount)
      value += amount
    end
    value = (value * rand(0.97..1.06)).round
    etf.asset_valuations.find_or_create_by!(valued_on: date) { |v| v.value_cents = value }
  end
end

# Budget: create the standard template rows, then fill a plausible household's
# worth of amounts. Only randomises once — a budget with any non-zero amounts
# is left alone.
BudgetItem.bootstrap_for(demo)
if demo.budget_items.where("amount_cents > 0").none?
  budget_amounts = {
    "income" => {
      "Income 1 (Post Tax)" => ["fortnightly", dollars.(2_800, 4_200)]
    },
    "bills" => {
      "Rent"                     => ["monthly", dollars.(1_800, 2_800)],
      "Electricity"              => ["quarterly", dollars.(250, 450)],
      "Gas"                      => ["quarterly", dollars.(120, 250)],
      "Internet"                 => ["monthly", dollars.(70, 110)],
      "Mobile phone/s"           => ["monthly", dollars.(30, 60)],
      "Car & Vehicle Insurances" => ["annually", dollars.(800, 1_600)],
      "Private Health Insurance" => ["monthly", dollars.(120, 250)],
      "Gym"                      => ["weekly", dollars.(15, 35)]
    },
    "everyday" => {
      "Groceries"                    => ["weekly", dollars.(120, 250)],
      "Petrol"                       => ["weekly", dollars.(40, 90)],
      "Restaurants & Take Aways"     => ["weekly", dollars.(40, 120)],
      "Movies, concerts, bars etc."  => ["monthly", dollars.(50, 150)],
      "Clothes & Shoes"              => ["monthly", dollars.(80, 200)]
    }
  }

  budget_amounts.each do |section, items|
    items.each do |name, (frequency, amount_cents)|
      demo.budget_items.find_by(section: section, name: name)
          &.update!(frequency: frequency, amount_cents: amount_cents)
    end
  end
end

puts "Seeded: #{User.count} users, #{UserAsset.count} assets, #{UserLiability.count} liabilities, " \
     "#{demo.budget_items.where("amount_cents > 0").count} filled budget items"
