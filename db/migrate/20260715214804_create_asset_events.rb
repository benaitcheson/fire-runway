class CreateAssetEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :asset_contributions do |t|
      t.references :user_asset, null: false, foreign_key: true
      t.date :occurred_on, null: false
      t.integer :amount_cents, null: false

      t.timestamps
    end
    add_index :asset_contributions, [:user_asset_id, :occurred_on]

    create_table :asset_valuations do |t|
      t.references :user_asset, null: false, foreign_key: true
      t.date :valued_on, null: false
      t.integer :value_cents, null: false

      t.timestamps
    end
    add_index :asset_valuations, [:user_asset_id, :valued_on], unique: true
  end
end
