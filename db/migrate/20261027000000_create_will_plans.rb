class CreateWillPlans < ActiveRecord::Migration[8.1]
  def change
    create_table :will_plans do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :state
      t.string :executor_name
      t.string :executor_relationship
      t.string :backup_executor_name
      t.string :guardian_name
      t.string :backup_guardian_name
      t.string :super_nomination
      t.string :super_nominee
      t.text :funeral_wishes
      t.text :other_wishes
      t.string :will_status, null: false, default: "not_started"
      t.date :signed_on
      t.string :stored_at
      t.timestamps
    end

    create_table :will_beneficiaries do |t|
      t.references :will_plan, null: false, foreign_key: true
      t.string :name, null: false
      t.string :relationship
      t.decimal :residue_share_pct, precision: 5, scale: 2, null: false, default: 0
      t.string :fallback, null: false, default: "their_children"
      t.string :fallback_name
      t.timestamps
    end

    create_table :will_asset_instructions do |t|
      t.references :will_plan, null: false, foreign_key: true
      t.references :user_asset, null: false, foreign_key: true
      t.references :will_beneficiary, foreign_key: { on_delete: :nullify }
      t.string :ownership, null: false, default: "sole"
      t.decimal :owned_share_pct, precision: 5, scale: 2
      t.timestamps
    end
    add_index :will_asset_instructions, [:will_plan_id, :user_asset_id], unique: true

    # Which asset, if any, a debt is secured on: a secured debt is paid from
    # that asset first, so it follows the asset rather than the residue.
    create_table :will_liability_instructions do |t|
      t.references :will_plan, null: false, foreign_key: true
      t.references :user_liability, null: false, foreign_key: true
      t.references :secured_asset, foreign_key: { to_table: :user_assets, on_delete: :nullify }
      t.timestamps
    end
    add_index :will_liability_instructions, [:will_plan_id, :user_liability_id], unique: true
  end
end
