class InvestmentComparisonController < ApplicationController
  def index
    from_user = user_defaults.compact
    @prefilled = from_user.keys
    @params = random_defaults.merge(from_user)
    @results = InvestmentComparison::Calculator.new(@params).call
  end

  def calculate
    @params = comparison_params
    @results = InvestmentComparison::Calculator.new(@params).call

    respond_to do |format|
      format.turbo_stream
      format.html { render :index }
    end
  end

  private

  def user_defaults
    {
      initial_capital: investable_capital,
      monthly_savings: monthly_surplus,
      salary: estimated_gross_salary,
      tax_rate: marginal_tax_rate,
      property_interest_rate: mortgage_rate
    }
  end

  # Current value of financial (non-depreciating) assets, excluding super,
  # which is locked away and not investable.
  def investable_capital
    cents = current_user.user_assets
      .where(depreciation_method: "none")
      .reject { |asset| asset.item_name.match?(/super/i) }
      .sum(&:current_value_cents)
    cents.positive? ? (cents / 100.0).round(-3) : nil
  end

  def monthly_surplus
    cents = current_user.monthly_budget_surplus_cents
    cents&.positive? ? (cents / 100.0).round(-2) : nil
  end

  # Budget income is net; approximate gross using a ~30% effective tax rate.
  def estimated_gross_salary
    net = budget_yearly_cents("income")
    net.positive? ? (net / 100.0 / 0.7).round(-3) : nil
  end

  def budget_yearly_cents(section)
    current_user.budget_items.in_section(section).sum(&:yearly_cents)
  end

  # Australian resident marginal bracket for the estimated salary, plus the
  # 2% Medicare levy. Nil below the tax-free threshold (form default applies).
  def marginal_tax_rate
    gross = estimated_gross_salary
    return nil unless gross

    bracket =
      case gross
      when 0...18_200 then nil
      when 18_200...45_000 then 16.0
      when 45_000...135_000 then 30.0
      when 135_000...190_000 then 37.0
      else 45.0
      end
    bracket && bracket + 2.0
  end

  # Rate from the largest entered mortgage/home-loan liability, if any.
  def mortgage_rate
    current_user.user_liabilities
      .where("item_name ~* ?", "mortgage|home loan")
      .where("interest_rate > 0")
      .order(amount_cents: :desc)
      .first&.interest_rate&.to_f&.round(1)
  end

  def random_defaults
    {
      initial_capital: rand(20..100) * 1_000,
      monthly_savings: rand(10..40) * 100,
      salary: rand(16..36) * 5_000,
      salary_growth_rate: rand(2.0..8.0).round(1),
      tax_rate: 37.0,
      timeframe: rand(3..6) * 5,
      property_price: rand(14..32) * 25_000,
      property_interest_rate: rand(5.5..7.5).round(1),
      property_rental_yield: rand(3.0..5.5).round(1),
      property_growth_rate: rand(3.0..7.0).round(1),
      nab_loan_amount: rand(4..20) * 25_000,
      nab_interest_rate: rand(6.5..9.0).round(1),
      nab_small_loan_premium: 2.0,
      nab_loan_term: [10, 15].sample,
      etf_return_rate: rand(7.0..12.0).round(1),
      etf_dividend_yield: rand(1.5..4.5).round(1),
      hybrid_property_year: rand(2..5),
      hybrid_nab_loan_amount: rand(2..6) * 25_000,
      max_properties: 5,
      etfs: default_etfs
    }
  end

  def default_etfs
    growth = rand(30..60).round(-1)
    mid = rand(10..(90 - growth)).round(-1)
    defensive = 100 - growth - mid
    [
      { name: "IVV", allocation: growth,    capital_return: 12.0, dividend_yield: 1.3 },
      { name: "MVW", allocation: mid,       capital_return: 8.0,  dividend_yield: 3.5 },
      { name: "VAP", allocation: defensive, capital_return: 6.5,  dividend_yield: 4.0 },
      { name: "",    allocation: 0,         capital_return: 0.0,  dividend_yield: 0.0 }
    ]
  end

  def comparison_params
    permitted = params.permit(
      :initial_capital, :monthly_savings, :salary, :salary_growth_rate,
      :tax_rate, :timeframe,
      :property_price, :property_interest_rate, :property_rental_yield,
      :property_growth_rate,
      :nab_loan_amount, :nab_interest_rate, :nab_small_loan_premium, :nab_loan_term,
      :etf_return_rate, :etf_dividend_yield,
      :hybrid_property_year, :hybrid_nab_loan_amount,
      :max_properties,
      etfs: [ :name, :allocation, :capital_return, :dividend_yield ]
    )

    result = permitted.to_h.deep_symbolize_keys

    # Parse ETFs and compute weighted blend
    if result[:etfs].present?
      etfs = result[:etfs].values.map do |etf|
        {
          name: etf[:name].to_s,
          allocation: etf[:allocation].to_f,
          capital_return: etf[:capital_return].to_f,
          dividend_yield: etf[:dividend_yield].to_f
        }
      end
      result[:etfs] = etfs
      result[:etf_return_rate] = etfs.sum { |e| (e[:allocation] / 100.0) * e[:capital_return] }
      result[:etf_dividend_yield] = etfs.sum { |e| (e[:allocation] / 100.0) * e[:dividend_yield] }
    else
      result[:etfs] = default_etfs
      result[:etf_return_rate] = result[:etf_return_rate].to_f
      result[:etf_dividend_yield] = result[:etf_dividend_yield].to_f
    end

    # Convert remaining numeric fields
    %i[initial_capital monthly_savings salary salary_growth_rate tax_rate timeframe
       property_price property_interest_rate property_rental_yield property_growth_rate
       nab_loan_amount nab_interest_rate nab_small_loan_premium nab_loan_term
       hybrid_property_year hybrid_nab_loan_amount max_properties].each do |key|
      result[key] = result[key].to_f if result[key]
    end

    result
  end
end
