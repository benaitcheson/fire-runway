class AddPayoffFieldsToUserLiabilities < ActiveRecord::Migration[8.1]
  def change
    add_column :user_liabilities, :interest_rate, :decimal, precision: 5, scale: 2, null: false, default: 0.0
    add_column :user_liabilities, :minimum_monthly_payment_cents, :integer, null: false, default: 0
  end
end
