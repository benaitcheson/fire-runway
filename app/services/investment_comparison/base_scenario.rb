module InvestmentComparison
  class BaseScenario
    include LoanMath

    def initialize(params)
      @params = params
      @initial_capital = params[:initial_capital].to_f
      @monthly_savings = params[:monthly_savings].to_f
      @salary = params[:salary].to_f
      @salary_growth_rate = params[:salary_growth_rate].to_f / 100.0
      @tax_rate = params[:tax_rate].to_f / 100.0
      @timeframe = params[:timeframe].to_i
    end

    def calculate
      raise NotImplementedError
    end

    private

    def nab_eb_rate(loan_amount, base_rate_over_250k, small_loan_premium)
      if loan_amount >= 250_000
        base_rate_over_250k
      else
        base_rate_over_250k + small_loan_premium
      end
    end

    def salary_at_year(year)
      capped = [@salary * (1 + @salary_growth_rate)**(year - 1), 200_000].min
      capped
    end

    def format_snapshot(year:, asset_value:, loan_balance:, equity:, annual_income:, annual_costs:, tax_benefit:, cumulative_invested:)
      {
        year: year,
        asset_value: asset_value.round(0),
        loan_balance: loan_balance.round(0),
        equity: equity.round(0),
        annual_income: annual_income.round(0),
        annual_costs: annual_costs.round(0),
        tax_benefit: tax_benefit.round(0),
        net_cashflow: (annual_income - annual_costs + tax_benefit).round(0),
        cumulative_invested: cumulative_invested.round(0)
      }
    end
  end
end
