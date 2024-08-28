class CreateUserAssets < ActiveRecord::Migration[7.1]
  def change
    create_table :user_assets do |t|
      t.string :item_name, null: false
      t.integer :purchase_price_cents, null: false
      t.string :purchase_price_currency, null: false, default: "AUD"
      t.date :purchase_date, null: false
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
