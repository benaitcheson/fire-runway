module InvestmentComparison
  class NabEbScenario < BaseScenario
    def initialize(params)
      super
      @nab_loan_amount = params[:nab_loan_amount].to_f
      base_rate = params[:nab_interest_rate].to_f / 100.0
      small_loan_premium = params[:nab_small_loan_premium].to_f / 100.0
      @nab_interest_rate = nab_eb_rate(@nab_loan_amount, base_rate, small_loan_premium)
      @nab_loan_term = params[:nab_loan_term].to_i
      @etf_return_rate = params[:etf_return_rate].to_f / 100.0
      @dividend_yield = params[:etf_dividend_yield].to_f / 100.0
      @franking_rate = 0.30 # Australian corporate tax rate for franking credits
    end

    def calculate
      # Own funds needed: to keep LVR at 75%, need 25% equity
      total_investment = @nab_loan_amount / 0.75
      own_funds = total_investment - @nab_loan_amount
      monthly_repayment = monthly_loan_repayment(@nab_loan_amount, @nab_interest_rate, @nab_loan_term)
      cumulative_invested = own_funds
      additional_shares = 0.0
      yearly_data = []

      (1..@timeframe).each do |year|
        # Portfolio value: initial investment grows + any additional purchases
        base_portfolio = compound_growth(total_investment, @etf_return_rate, year)

        # Additional shares purchased after loan paid off
        if year > @nab_loan_term
          years_of_extra = year - @nab_loan_term
          # After loan paid off, monthly repayment + monthly savings go into shares
          annual_contribution = (monthly_repayment + @monthly_savings) * 12
          # Future value of annuity for the extra contributions
          additional_shares = annual_contribution * (((1 + @etf_return_rate)**years_of_extra - 1) / @etf_return_rate)
        end

        portfolio_value = base_portfolio + additional_shares

        # Loan balance
        if year <= @nab_loan_term
          loan_balance = remaining_loan_balance(@nab_loan_amount, @nab_interest_rate, @nab_loan_term, year * 12)
        else
          loan_balance = 0.0
        end

        # Dividends (on growing portfolio)
        dividends = portfolio_value * @dividend_yield

        # Interest cost
        if year <= @nab_loan_term
          interest = annual_interest_paid(@nab_loan_amount, @nab_interest_rate, @nab_loan_term, year)
          annual_repayments = monthly_repayment * 12
        else
          interest = 0.0
          annual_repayments = 0.0
        end

        # Tax: interest is deductible, dividends are assessable with franking credits
        # Assume ~70% of dividends are franked (Australian shares)
        franked_pct = 0.70
        franking_credits = dividends * franked_pct * (@franking_rate / (1 - @franking_rate))
        gross_dividends = dividends + franking_credits
        net_taxable = gross_dividends - interest
        if net_taxable < 0
          tax_benefit = net_taxable.abs * @tax_rate
        else
          tax_benefit = franking_credits # franking credits offset tax
        end

        # Net out of pocket: repayments - dividends
        if year <= @nab_loan_term
          net_cost = annual_repayments - dividends
          cumulative_invested += [net_cost, 0].max
        else
          # After loan paid off, investing monthly savings
          cumulative_invested += @monthly_savings * 12
        end

        equity = portfolio_value - loan_balance

        yearly_data << format_snapshot(
          year: year,
          asset_value: portfolio_value,
          loan_balance: loan_balance,
          equity: equity,
          annual_income: dividends,
          annual_costs: annual_repayments,
          tax_benefit: tax_benefit,
          cumulative_invested: cumulative_invested
        )
      end

      { name: "NAB Equity Builder", color: "#3b82f6", yearly_data: yearly_data, upfront: own_funds.round(0) }
    end
  end
end
