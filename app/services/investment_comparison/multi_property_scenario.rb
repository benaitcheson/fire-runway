module InvestmentComparison
  class MultiPropertyScenario < BaseScenario
    def initialize(params)
      super
      @property_price = params[:property_price].to_f
      @property_interest_rate = params[:property_interest_rate].to_f / 100.0
      @rental_yield = params[:property_rental_yield].to_f / 100.0
      @growth_rate = params[:property_growth_rate].to_f / 100.0
      @annual_costs_pct = 0.015
      @management_fee_pct = 0.08
      @deposit_pct = 0.20
      @max_properties = (params[:max_properties] || 5).to_i
    end

    def calculate
      properties = []
      cumulative_invested = 0.0
      savings_pool = @initial_capital
      yearly_data = []

      # Buy first property at year 0
      buy_property!(properties, 0, savings_pool)
      savings_pool -= first_property_upfront
      cumulative_invested += first_property_upfront

      (1..@timeframe).each do |year|
        # Update all property values
        properties.each do |prop|
          years_held = year - prop[:purchased_year]
          prop[:current_value] = compound_growth(prop[:purchase_price], @growth_rate, years_held)
          prop[:loan_balance] = remaining_loan_balance(prop[:loan_amount], @property_interest_rate, 30, years_held * 12)
        end

        # Total portfolio position
        total_value = properties.sum { |p| p[:current_value] }
        total_debt = properties.sum { |p| p[:loan_balance] }
        total_equity = total_value - total_debt

        # Income and costs for all properties
        total_rent = 0.0
        total_costs = 0.0
        total_interest = 0.0

        properties.each do |prop|
          years_held = year - prop[:purchased_year]
          rent = prop[:current_value] * @rental_yield
          management = rent * @management_fee_pct
          ongoing = prop[:current_value] * @annual_costs_pct
          mortgage = monthly_loan_repayment(prop[:loan_amount], @property_interest_rate, 30) * 12
          interest = annual_interest_paid(prop[:loan_amount], @property_interest_rate, 30, years_held)

          total_rent += rent
          total_costs += mortgage + management + ongoing
          total_interest += interest
        end

        # Net out of pocket
        net_out_of_pocket = total_costs - total_rent
        cumulative_invested += [net_out_of_pocket, 0].max

        # Accumulate savings for next property
        monthly_spare = @monthly_savings - (net_out_of_pocket / 12.0)
        savings_pool += [monthly_spare, 0].max * 12

        # Tax benefit from negative gearing across all properties
        total_deductible = total_interest + (total_rent * @management_fee_pct) + (total_value * @annual_costs_pct)
        taxable = total_rent - total_deductible
        tax_benefit = taxable < 0 ? (taxable.abs * @tax_rate) : 0

        # Can we buy another property?
        # Need: usable equity (80% of total equity) OR savings pool covers deposit + stamp duty
        if properties.length < @max_properties
          next_price = @property_price * (1 + @growth_rate)**year # prices have grown too
          next_deposit = next_price * @deposit_pct
          next_stamp = estimate_stamp_duty(next_price)
          next_upfront = next_deposit + next_stamp

          # Usable equity: banks typically lend against 80% of property value minus existing debt
          usable_equity = (total_value * 0.80) - total_debt
          available = savings_pool + [usable_equity, 0].max

          if available >= next_upfront && can_service_new_loan?(properties, next_price, year)
            buy_property!(properties, year, next_upfront)
            savings_pool = [savings_pool - next_upfront, 0].max
            cumulative_invested += next_upfront
          end
        end

        yearly_data << format_snapshot(
          year: year,
          asset_value: total_value,
          loan_balance: total_debt,
          equity: total_equity,
          annual_income: total_rent,
          annual_costs: total_costs,
          tax_benefit: tax_benefit,
          cumulative_invested: cumulative_invested
        ).merge(property_count: properties.length)
      end

      upfront = first_property_upfront
      { name: "Property Snowball (max #{@max_properties})", color: "#f59e0b", yearly_data: yearly_data, upfront: upfront.round(0) }
    end

    private

    def first_property_upfront
      deposit = @property_price * @deposit_pct
      stamp = estimate_stamp_duty(@property_price)
      deposit + stamp
    end

    def buy_property!(properties, year, _funds_used)
      price = year == 0 ? @property_price : @property_price * (1 + @growth_rate)**year
      loan = price * (1 - @deposit_pct)
      properties << {
        purchase_price: price,
        loan_amount: loan,
        current_value: price,
        loan_balance: loan,
        purchased_year: year
      }
    end

    def can_service_new_loan?(existing_properties, new_price, year)
      # Simplified serviceability check:
      # Total monthly repayments (existing + new) must be less than
      # monthly savings + total rental income
      new_loan = new_price * (1 - @deposit_pct)
      new_monthly = monthly_loan_repayment(new_loan, @property_interest_rate, 30)

      existing_repayments = existing_properties.sum do |p|
        monthly_loan_repayment(p[:loan_amount], @property_interest_rate, 30)
      end

      total_rent_monthly = existing_properties.sum { |p| p[:current_value] * @rental_yield / 12.0 }
      # Banks use ~80% of rental income for serviceability
      usable_rent = total_rent_monthly * 0.80
      new_rent = (new_price * @rental_yield / 12.0) * 0.80

      salary_monthly = salary_at_year(year) / 12.0
      total_repayments = existing_repayments + new_monthly
      total_income = usable_rent + new_rent + salary_monthly

      # Debt-to-income ratio: repayments should be under 40% of income
      total_repayments < (total_income * 0.40)
    end

    def estimate_stamp_duty(price)
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
