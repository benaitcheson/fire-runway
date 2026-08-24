class LoanTaxController < ApplicationController
  LOAN_TYPES = %w[principal_and_interest interest_only].freeze

  # GET /loan_tax
  def index
    load_inputs
    remember_settings if params[:gross_salary].present?

    @result = LoanTax::Simulator.new(
      gross_salary: @gross_salary, loan_amount: @loan_amount,
      interest_rate_pct: @interest_rate, loan_type: @loan_type,
      term_years: @term_years, dividend_yield_pct: @dividend_yield,
      franking_pct: @franking_pct, capital_growth_pct: @capital_growth,
      has_hecs: @has_hecs, hecs_balance: @has_hecs ? @hecs_balance : nil,
      private_hospital_cover: @private_hospital_cover
    ).call
    return unless @result

    @chart_data = [
      { name: "Investment value", data: chart_series(:investment_value), color: "#10b981" },
      { name: "Loan balance", data: chart_series(:closing_balance), color: "#ef4444" },
      { name: "Cumulative net cashflow", data: chart_series(:cumulative_cashflow), color: "#3b82f6" }
    ]
  end

  private

  # Precedence for every input: typed params > saved settings > default.
  def load_inputs
    user = current_user
    @gross_salary = float_param(:gross_salary) ||
                    from_cents(user.loan_tax_gross_salary_cents) || 120_000
    @loan_amount = float_param(:loan_amount) ||
                   from_cents(user.loan_tax_loan_amount_cents) || 100_000
    @interest_rate = float_param(:interest_rate) ||
                     user.loan_tax_interest_rate&.to_f || 8.0
    @loan_type = params[:loan_type].presence || user.loan_tax_loan_type ||
                 "principal_and_interest"
    @loan_type = "principal_and_interest" unless LOAN_TYPES.include?(@loan_type)
    @term_years = (params[:term_years].presence || user.loan_tax_term_years || 10).to_i
    @dividend_yield = float_param(:dividend_yield) ||
                      user.loan_tax_dividend_yield&.to_f || 4.0
    @franking_pct = float_param(:franking_pct) ||
                    user.loan_tax_franking_pct&.to_f || 100.0
    @capital_growth = float_param(:capital_growth) ||
                      user.loan_tax_capital_growth&.to_f || 5.0
    @has_hecs = boolean_input(:has_hecs, user.loan_tax_has_hecs)
    @hecs_balance = float_param(:hecs_balance) ||
                    from_cents(user.loan_tax_hecs_balance_cents)
    @private_hospital_cover = boolean_input(:private_hospital_cover,
                                            user.loan_tax_private_hospital_cover)

    %i[@gross_salary @loan_amount @interest_rate @dividend_yield @franking_pct
       @capital_growth @hecs_balance].each do |ivar|
      value = instance_variable_get(ivar)
      instance_variable_set(ivar, value.to_i) if value && (value % 1).zero?
    end
  end

  def float_param(key)
    params[key].presence&.to_f
  end

  def from_cents(cents)
    cents && cents / 100.0
  end

  # form.check_box submits "0"/"1" (hidden field included), so a submitted
  # form always carries the key; otherwise fall back to the saved setting.
  def boolean_input(key, saved)
    if params.key?(key)
      ActiveModel::Type::Boolean.new.cast(params[key]) || false
    else
      saved || false
    end
  end

  # Remember the last recalculated inputs so the page reopens with them.
  def remember_settings
    current_user.update!(
      loan_tax_gross_salary_cents: (@gross_salary.to_f * 100).round,
      loan_tax_loan_amount_cents: (@loan_amount.to_f * 100).round,
      loan_tax_interest_rate: @interest_rate,
      loan_tax_loan_type: @loan_type,
      loan_tax_term_years: @term_years,
      loan_tax_dividend_yield: @dividend_yield,
      loan_tax_franking_pct: @franking_pct,
      loan_tax_capital_growth: @capital_growth,
      loan_tax_has_hecs: @has_hecs,
      loan_tax_hecs_balance_cents: @hecs_balance ? (@hecs_balance.to_f * 100).round : nil,
      loan_tax_private_hospital_cover: @private_hospital_cover
    )
  end

  def chart_series(field)
    @result.years.to_h { |row| ["Year #{row.year}", row.public_send(field).round(2)] }
  end
end
