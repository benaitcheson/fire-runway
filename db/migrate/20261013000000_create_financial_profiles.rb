# One "fact finder" profile per user: the facts a financial planner asks for
# that are about the person rather than any one calculator page. The person
# fields the forecast and loan tax pages had on users now live here.
class CreateFinancialProfiles < ActiveRecord::Migration[8.1]
  def change
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

    remove_column :users, :forecast_birth_year, :integer
    remove_column :users, :forecast_retirement_age, :integer
    remove_column :users, :forecast_retirement_spend_cents, :bigint
    remove_column :users, :loan_tax_gross_salary_cents, :bigint
    remove_column :users, :loan_tax_has_hecs, :boolean
    remove_column :users, :loan_tax_hecs_balance_cents, :bigint
    remove_column :users, :loan_tax_private_hospital_cover, :boolean
  end
end
