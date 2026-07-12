module InvestmentComparison
  class HybridScenario < BaseScenario
    def initialize(params)
      super
      @hybrid_property_year = params[:hybrid_property_year].to_i
      @hybrid_nab_loan_amount = params[:hybrid_nab_loan_amount].to_f

      # NAB EB params (tiered rate)
      base_rate = params[:nab_interest_rate].to_f / 100.0
      small_loan_premium = params[:nab_small_loan_premium].to_f / 100.0
      @nab_interest_rate = nab_eb_rate(@hybrid_nab_loan_amount, base_rate, small_loan_premium)
      @nab_loan_term = params[:nab_loan_term].to_i
      @etf_return_rate = params[:etf_return_rate].to_f / 100.0
      @dividend_yield = params[:etf_dividend_yield].to_f / 100.0

      # Property params
      @property_price = params[:property_price].to_f
      @property_interest_rate = params[:property_interest_rate].to_f / 100.0
      @rental_yield = params[:property_rental_yield].to_f / 100.0
      @property_growth_rate = params[:property_growth_rate].to_f / 100.0
      @annual_costs_pct = 0.015
      @management_fee_pct = 0.08
      @stamp_duty = estimate_stamp_duty(@property_price)
      @deposit_pct = 0.20
    end

    def calculate
      # Phase 1: NAB EB only, saving remainder for property deposit
      nab_total = @hybrid_nab_loan_amount / 0.75
      nab_own_funds = nab_total - @hybrid_nab_loan_amount
      nab_monthly = monthly_loan_repayment(@hybrid_nab_loan_amount, @nab_interest_rate, @nab_loan_term)

      property_deposit = @property_price * @deposit_pct
      property_loan = @property_price - property_deposit
      property_monthly = monthly_loan_repayment(property_loan, @property_interest_rate, 30)

      cumulative_invested = nab_own_funds
      savings_pool = @initial_capital - nab_own_funds # remaining cash after EB equity
      property_active = false
      yearly_data = []

      (1..@timeframe).each do |year|
        # --- NAB EB Portfolio ---
        nab_portfolio = compound_growth(nab_total, @etf_return_rate, year)

        # Additional contributions after EB loan paid off
        nab_additional = 0.0
        if year > @nab_loan_term
          years_extra = year - @nab_loan_term
          extra_monthly = nab_monthly # freed up repayments go to more shares
          nab_additional = (extra_monthly * 12) * (((1 + @etf_return_rate)**years_extra - 1) / @etf_return_rate)
        end
        nab_value = nab_portfolio + nab_additional

        nab_loan_balance = year <= @nab_loan_term ? remaining_loan_balance(@hybrid_nab_loan_amount, @nab_interest_rate, @nab_loan_term, year * 12) : 0.0
        nab_dividends = nab_value * @dividend_yield
        nab_interest = year <= @nab_loan_term ? annual_interest_paid(@hybrid_nab_loan_amount, @nab_interest_rate, @nab_loan_term, year) : 0.0
        nab_repayments = year <= @nab_loan_term ? nab_monthly * 12 : 0.0

        # --- Savings accumulation before property purchase ---
        if !property_active && year < @hybrid_property_year
          monthly_spare = @monthly_savings - (nab_monthly - nab_dividends / 12.0)
          savings_pool += [monthly_spare, 0].max * 12
          cumulative_invested += (nab_repayments - nab_dividends).clamp(0, Float::INFINITY)
        end

        # --- Property (if active) ---
        property_value = 0.0
        property_loan_balance = 0.0
        property_rent = 0.0
        property_costs = 0.0
        property_tax_benefit = 0.0

        if year == @hybrid_property_year && !property_active
          property_active = true
          cumulative_invested += property_deposit + @stamp_duty
        end

        if property_active
          property_years = year - @hybrid_property_year + 1
          property_value = compound_growth(@property_price, @property_growth_rate, property_years)
          property_loan_balance = remaining_loan_balance(property_loan, @property_interest_rate, 30, property_years * 12)

          property_rent = property_value * @rental_yield
          management = property_rent * @management_fee_pct
          ongoing = property_value * @annual_costs_pct
          prop_interest = annual_interest_paid(property_loan, @property_interest_rate, 30, property_years)
          property_costs = property_monthly * 12 + management + ongoing

          # Negative gearing
          deductible = prop_interest + management + ongoing
          taxable = property_rent - deductible
          property_tax_benefit = taxable < 0 ? (taxable.abs * @tax_rate) : 0

          net_property_cost = property_costs - property_rent
          cumulative_invested += [net_property_cost, 0].max
        end

        if year > @nab_loan_term && !property_active
          cumulative_invested += @monthly_savings * 12
        elsif year > @nab_loan_term && property_active
          # Freed EB repayments offset property costs
        end

        # NAB tax benefit
        franking_credits = nab_dividends * 0.70 * (0.30 / 0.70)
        nab_net_taxable = (nab_dividends + franking_credits) - nab_interest
        nab_tax_benefit = nab_net_taxable < 0 ? (nab_net_taxable.abs * @tax_rate) : franking_credits

        # Combined totals
        total_asset_value = nab_value + property_value
        total_loan_balance = nab_loan_balance + property_loan_balance
        total_equity = total_asset_value - total_loan_balance
        total_income = nab_dividends + property_rent
        total_costs = nab_repayments + property_costs
        total_tax = nab_tax_benefit + property_tax_benefit

        yearly_data << format_snapshot(
          year: year,
          asset_value: total_asset_value,
          loan_balance: total_loan_balance,
          equity: total_equity,
          annual_income: total_income,
          annual_costs: total_costs,
          tax_benefit: total_tax,
          cumulative_invested: cumulative_invested
        )
      end

      upfront = nab_own_funds + property_deposit + @stamp_duty
      { name: "Hybrid (EB + Property)", color: "#8b5cf6", yearly_data: yearly_data, upfront: upfront.round(0) }
    end

    private

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
