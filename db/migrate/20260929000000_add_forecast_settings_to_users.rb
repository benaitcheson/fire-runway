class AddForecastSettingsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :forecast_birth_year, :integer
    add_column :users, :forecast_retirement_age, :integer
    add_column :users, :forecast_horizon_years, :integer
    add_column :users, :forecast_annual_growth, :decimal, precision: 5, scale: 2
    add_column :users, :forecast_inflation, :decimal, precision: 5, scale: 2
    add_column :users, :forecast_monthly_contribution_cents, :bigint
    add_column :users, :forecast_retirement_spend_cents, :bigint
  end
end
