module InvestmentComparison
  class PropertyScenario < BaseScenario
    def initialize(params)
      super
      @property_price = params[:property_price].to_f
      @property_interest_rate = params[:property_interest_rate].to_f / 100.0
      @rental_yield = params[:property_rental_yield].to_f / 100.0
      @growth_rate = params[:property_growth_rate].to_f / 100.0
      @annual_costs_pct = 0.015 # rates, insurance, maintenance as % of property value
      @management_fee_pct = 0.08 # property management fee as % of rent
      @stamp_duty = estimate_stamp_duty(@property_price)
      @deposit_pct = 0.20
    end

    def calculate
      deposit = @property_price * @deposit_pct
      loan = @property_price - deposit
      upfront = deposit + @stamp_duty
      monthly_repayment = monthly_loan_repayment(loan, @property_interest_rate, 30)
      cumulative_invested = upfront
      yearly_data = []

      (1..@timeframe).each do |year|
        property_value = compound_growth(@property_price, @growth_rate, year)
        loan_balance = remaining_loan_balance(loan, @property_interest_rate, 30, year * 12)

        annual_rent = property_value * @rental_yield
        management_cost = annual_rent * @management_fee_pct
        ongoing_costs = property_value * @annual_costs_pct
        interest = annual_interest_paid(loan, @property_interest_rate, 30, year)
        mortgage_annual = monthly_repayment * 12

        net_out_of_pocket = mortgage_annual - annual_rent + management_cost + ongoing_costs
        cumulative_invested += [net_out_of_pocket, 0].max

        # Negative gearing tax benefit
        total_deductible = interest + management_cost + ongoing_costs
        taxable_income = annual_rent - total_deductible
        tax_benefit = taxable_income < 0 ? (taxable_income.abs * @tax_rate) : 0

        equity = property_value - loan_balance

        yearly_data << format_snapshot(
          year: year,
          asset_value: property_value,
          loan_balance: loan_balance,
          equity: equity,
          annual_income: annual_rent,
          annual_costs: mortgage_annual + management_cost + ongoing_costs,
          tax_benefit: tax_benefit,
          cumulative_invested: cumulative_invested
        )
      end

      { name: "Investment Property", color: "#10b981", yearly_data: yearly_data, upfront: upfront.round(0) }
    end

    private

    def estimate_stamp_duty(price)
      # Simplified NSW stamp duty estimate
      if price <= 14_000
        price * 0.0125
      elsif price <= 32_000
        175 + (price - 14_000) * 0.015
      elsif price <= 85_000
        445 + (price - 32_000) * 0.0175
      elsif price <= 319_000
        1372.50 + (price - 85_000) * 0.035
      elsif price <= 1_064_000
        9562.50 + (price - 319_000) * 0.045
      else
        43087.50 + (price - 1_064_000) * 0.055
      end
    end
  end
end
