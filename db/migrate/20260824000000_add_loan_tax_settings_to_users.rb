class AddLoanTaxSettingsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :loan_tax_gross_salary_cents, :bigint
    add_column :users, :loan_tax_loan_amount_cents, :bigint
    add_column :users, :loan_tax_interest_rate, :decimal, precision: 5, scale: 2
    add_column :users, :loan_tax_loan_type, :string
    add_column :users, :loan_tax_term_years, :integer
    add_column :users, :loan_tax_dividend_yield, :decimal, precision: 5, scale: 2
    add_column :users, :loan_tax_franking_pct, :decimal, precision: 5, scale: 2
    add_column :users, :loan_tax_capital_growth, :decimal, precision: 5, scale: 2
    add_column :users, :loan_tax_has_hecs, :boolean
    add_column :users, :loan_tax_hecs_balance_cents, :bigint
    add_column :users, :loan_tax_private_hospital_cover, :boolean
  end
end
