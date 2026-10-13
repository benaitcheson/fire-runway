# One "fact finder" profile per user: the facts a financial planner asks for
# that are about the person rather than any one calculator page. The columns
# that the forecast and loan tax pages had been stashing on users move here so
# there is a single source of truth that the AI assistant can read.
class CreateFinancialProfiles < ActiveRecord::Migration[8.1]
  MOVED = {
    forecast_birth_year: [:birth_year, :integer],
    forecast_retirement_age: [:target_retirement_age, :integer],
    forecast_retirement_spend_cents: [:retirement_spend_monthly_cents, :bigint],
    loan_tax_gross_salary_cents: [:gross_salary_cents, :bigint],
    loan_tax_has_hecs: [:has_hecs, :boolean],
    loan_tax_hecs_balance_cents: [:hecs_balance_cents, :bigint],
    loan_tax_private_hospital_cover: [:private_hospital_cover, :boolean]
  }.freeze

  def up
    create_table :financial_profiles do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }

      # About you
      t.integer :birth_year
      t.string :relationship_status
      t.integer :dependants_count

      # Income and work
      t.string :employment_type
      t.bigint :gross_salary_cents
      t.string :income_stability
      t.bigint :partner_gross_salary_cents

      # Super and tax
      t.bigint :super_balance_cents
      t.decimal :super_employer_rate, precision: 5, scale: 2
      t.bigint :super_salary_sacrifice_monthly_cents
      t.boolean :has_hecs
      t.bigint :hecs_balance_cents
      t.boolean :private_hospital_cover

      # Home
      t.string :housing_status

      # Goals
      t.integer :target_retirement_age
      t.bigint :retirement_spend_monthly_cents
      t.integer :emergency_fund_months
      t.text :goals

      # Attitudes
      t.string :risk_tolerance
      t.string :investment_experience
      t.text :concerns

      # Protection and estate
      t.boolean :has_income_protection
      t.boolean :has_life_insurance
      t.boolean :has_will

      t.text :notes
      t.timestamps
    end

    old_cols = MOVED.keys.join(", ")
    new_cols = MOVED.values.map(&:first).join(", ")
    any_set = MOVED.keys.map { |c| "#{c} IS NOT NULL" }.join(" OR ")
    execute <<~SQL
      INSERT INTO financial_profiles (user_id, #{new_cols}, created_at, updated_at)
      SELECT id, #{old_cols}, NOW(), NOW() FROM users WHERE #{any_set}
    SQL

    MOVED.each_key { |column| remove_column :users, column }
  end

  def down
    MOVED.each do |old, (_new, type)|
      add_column :users, old, type
    end
    assignments = MOVED.map { |old, (new, _)| "#{old} = financial_profiles.#{new}" }.join(", ")
    execute <<~SQL
      UPDATE users SET #{assignments}
      FROM financial_profiles WHERE financial_profiles.user_id = users.id
    SQL
    drop_table :financial_profiles
  end
end
