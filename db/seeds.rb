# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

demo = User.find_or_create_by!(email: "demo@example.com") do |user|
  user.password = "password123"
end
demo.confirm!

assets = [
  { item_name: "Car", purchase_price_cents: 2_500_000, purchase_date: Date.new(2020, 3, 1),
    depreciation_method: "straight_line", useful_life_years: 10, salvage_value_cents: 250_000 },
  { item_name: "Laptop", purchase_price_cents: 320_000, purchase_date: Date.new(2023, 1, 15),
    depreciation_method: "straight_line", useful_life_years: 5, salvage_value_cents: 0 },
  { item_name: "Motorbike", purchase_price_cents: 800_000, purchase_date: Date.new(2021, 6, 20),
    depreciation_method: "declining_balance", depreciation_rate: 20.0, salvage_value_cents: 0 },
  { item_name: "Cash savings", purchase_price_cents: 4_000_000, purchase_date: Date.new(2025, 1, 1),
    depreciation_method: "none" },
  { item_name: "ETF portfolio", purchase_price_cents: 6_500_000, purchase_date: Date.new(2025, 1, 1),
    depreciation_method: "none" },
  { item_name: "Superannuation", purchase_price_cents: 9_000_000, purchase_date: Date.new(2025, 1, 1),
    depreciation_method: "none" }
]

assets.each do |attrs|
  demo.user_assets.find_or_create_by!(item_name: attrs[:item_name]) do |asset|
    asset.assign_attributes(purchase_price_currency: "AUD", **attrs)
  end
end

demo.user_liabilities.find_or_create_by!(item_name: "HECS debt") do |liability|
  liability.amount_cents = 3_000_000
  liability.amount_currency = "AUD"
end

puts "Seeded: #{User.count} users, #{UserAsset.count} assets, #{UserLiability.count} liabilities"
