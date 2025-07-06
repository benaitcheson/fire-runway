class CreateUserLiabilities < ActiveRecord::Migration[8.1]
  def change
    create_table :user_liabilities do |t|
      t.string :item_name, null: false
      t.integer :amount_cents, null: false
      t.string :amount_currency, default: "AUD", null: false
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
