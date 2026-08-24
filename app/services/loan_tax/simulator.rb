module LoanTax
  # Models the tax and wealth outcomes of borrowing to invest: amortises the
  # loan, grows the investment, and runs a with-loan and without-loan tax
  # assessment for every year of the term. All amounts are dollars (floats);
  # salary is held constant and dividends are taken as cash, not reinvested.
  class Simulator
    include LoanMath

    COMPANY_TAX_RATE = 0.30

    Result = Struct.new(:year_one, :years, :verdict, keyword_init: true)

    YearRow = Struct.new(
      :year, :opening_balance, :closing_balance, :interest, :principal_repaid,
      :repayments, :investment_value, :dividends, :franking_credits,
      :net_investment_income, :tax_saved, :hecs_with, :hecs_without,
      :net_cashflow, :cumulative_cashflow, :equity, keyword_init: true
    )

    YearOne = Struct.new(
      :with_loan, :without_loan, :tax_saved, :take_home_delta, :hecs_delta,
      :effective_interest_rate, :marginal_rate, :gearing_position,
      keyword_init: true
    )

    Verdict = Struct.new(
      :after_tax_cost_of_debt_pct, :assumed_total_return_pct, :break_even,
      :total_interest, :total_tax_saved, :end_investment_value, :end_equity,
      :net_wealth_delta, :interest_only, keyword_init: true
    )

    def initialize(gross_salary:, loan_amount:, interest_rate_pct:, loan_type:,
                   term_years:, dividend_yield_pct: 0.0, franking_pct: 100.0,
                   capital_growth_pct: 0.0, has_hecs: false, hecs_balance: nil,
                   private_hospital_cover: false)
      @salary = gross_salary.to_f
      @loan_amount = loan_amount.to_f
      @rate = interest_rate_pct.to_f / 100.0
      @interest_only = loan_type.to_s == "interest_only"
      @term = term_years.to_i
      @dividend_yield = dividend_yield_pct.to_f / 100.0
      @franking = franking_pct.to_f.clamp(0.0, 100.0) / 100.0
      @growth = capital_growth_pct.to_f / 100.0
      @has_hecs = has_hecs
      @hecs_balance = hecs_balance&.to_f
      @private_hospital_cover = private_hospital_cover
    end

    def call
      return nil if @loan_amount <= 0 || @term <= 0 || @rate < 0

      hecs_with = @hecs_balance
      hecs_without = @hecs_balance
      cumulative = 0.0
      years = []

      (1..@term).each do |year|
        opening, closing, interest, repayments = loan_leg(year)

        value_start = @loan_amount * (1 + @growth)**(year - 1)
        value_end = value_start * (1 + @growth)
        dividends = value_start * @dividend_yield
        franking_credits = dividends * @franking *
                           (COMPANY_TAX_RATE / (1 - COMPANY_TAX_RATE))
        grossed_dividends = dividends + franking_credits

        net_investment_income = grossed_dividends - interest
        net_investment_loss = [-net_investment_income, 0.0].max

        with_loan = Tax::AustralianResident.assess(
          taxable_income: @salary + grossed_dividends - interest,
          franking_credits: franking_credits,
          net_investment_loss: net_investment_loss,
          has_hecs: @has_hecs, hecs_balance: hecs_with,
          private_hospital_cover: @private_hospital_cover
        )
        without_loan = Tax::AustralianResident.assess(
          taxable_income: @salary,
          has_hecs: @has_hecs, hecs_balance: hecs_without,
          private_hospital_cover: @private_hospital_cover
        )
        hecs_with -= with_loan.hecs_repayment if hecs_with
        hecs_without -= without_loan.hecs_repayment if hecs_without

        tax_saved = without_loan.total_payable - with_loan.total_payable
        net_cashflow = dividends + tax_saved - repayments
        cumulative += net_cashflow

        years << YearRow.new(
          year: year, opening_balance: opening, closing_balance: closing,
          interest: interest, principal_repaid: repayments - interest,
          repayments: repayments, investment_value: value_end,
          dividends: dividends, franking_credits: franking_credits,
          net_investment_income: net_investment_income, tax_saved: tax_saved,
          hecs_with: with_loan.hecs_repayment,
          hecs_without: without_loan.hecs_repayment,
          net_cashflow: net_cashflow, cumulative_cashflow: cumulative,
          equity: value_end - closing
        )

        @year_one_assessments ||= [with_loan, without_loan]
      end

      Result.new(year_one: build_year_one(years.first),
                 years: years,
                 verdict: build_verdict(years))
    end

    private

    # Returns [opening balance, closing balance, interest, total repayments]
    # for the year. Interest-only never amortises — the principal falls due
    # at the end of the term (the verdict calls this out).
    def loan_leg(year)
      if @interest_only
        interest = @loan_amount * @rate
        [@loan_amount, @loan_amount, interest, interest]
      else
        [remaining_loan_balance(@loan_amount, @rate, @term, (year - 1) * 12),
         remaining_loan_balance(@loan_amount, @rate, @term, year * 12),
         annual_interest_paid(@loan_amount, @rate, @term, year),
         monthly_loan_repayment(@loan_amount, @rate, @term) * 12]
      end
    end

    def build_year_one(row)
      with_loan, without_loan = @year_one_assessments
      tax_saved = row.tax_saved

      gearing_position =
        if row.net_investment_income < -0.01 then :negative
        elsif row.net_investment_income > 0.01 then :positive
        else :neutral
        end

      YearOne.new(
        with_loan: with_loan, without_loan: without_loan,
        tax_saved: tax_saved,
        take_home_delta: row.dividends - row.interest + tax_saved,
        hecs_delta: without_loan.hecs_repayment - with_loan.hecs_repayment,
        effective_interest_rate: (row.interest - tax_saved) / @loan_amount * 100,
        marginal_rate: Tax::AustralianResident.marginal_rate(@salary),
        gearing_position: gearing_position
      )
    end

    def build_verdict(years)
      last = years.last
      # Cost of the interest deduction in isolation (no investment income),
      # so the hurdle rate is comparable across yield assumptions.
      interest = years.first.interest
      deduction_saving =
        Tax::AustralianResident.assess(taxable_income: @salary).total_payable -
        Tax::AustralianResident.assess(taxable_income: @salary - interest,
                                       net_investment_loss: interest).total_payable
      after_tax_cost = (interest - deduction_saving) / @loan_amount * 100

      franking_uplift = @dividend_yield * @franking *
                        (COMPANY_TAX_RATE / (1 - COMPANY_TAX_RATE))
      assumed_return = (@dividend_yield + @growth + franking_uplift) * 100

      Verdict.new(
        after_tax_cost_of_debt_pct: after_tax_cost,
        assumed_total_return_pct: assumed_return,
        break_even: assumed_return >= after_tax_cost,
        total_interest: years.sum(&:interest),
        total_tax_saved: years.sum(&:tax_saved),
        end_investment_value: last.investment_value,
        end_equity: last.equity,
        net_wealth_delta: last.equity + last.cumulative_cashflow,
        interest_only: @interest_only
      )
    end
  end
end
