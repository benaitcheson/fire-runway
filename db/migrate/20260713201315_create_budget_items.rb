class CreateBudgetItems < ActiveRecord::Migration[8.1]
  def change
    create_table :budget_items do |t|
      t.references :user, null: false, foreign_key: true
      t.string :section, null: false
      t.string :name, null: false
      t.integer :amount_cents, null: false, default: 0
      t.string :frequency, null: false, default: "weekly"
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :budget_items, [:user_id, :section, :name], unique: true
  end
end
