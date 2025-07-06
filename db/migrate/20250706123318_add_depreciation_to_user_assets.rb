class AddDepreciationToUserAssets < ActiveRecord::Migration[8.1]
  def change
    add_column :user_assets, :depreciation_method, :string, default: 'none'
    add_column :user_assets, :depreciation_rate, :decimal, precision: 5, scale: 2
    add_column :user_assets, :useful_life_years, :integer
    add_column :user_assets, :salvage_value_cents, :integer, default: 0
  end
end
