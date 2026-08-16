class AddRunwaySettingsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :runway_monthly_spend_cents, :integer
    add_column :users, :runway_annual_growth, :decimal, precision: 5, scale: 2
  end
end
