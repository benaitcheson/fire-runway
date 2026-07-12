class InvestmentComparisonController < ApplicationController
  def index
    @params = default_params
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

  def default_params
    {
      initial_capital: 56_000,
      monthly_savings: 2_400,
      salary: 120_000,
      salary_growth_rate: 10.0,
      tax_rate: 37.0,
      timeframe: 25,
      property_price: 400_000,
      property_interest_rate: 6.5,
      property_rental_yield: 4.0,
      property_growth_rate: 5.0,
      nab_loan_amount: 300_000,
      nab_interest_rate: 7.5,
      nab_small_loan_premium: 2.0,
      nab_loan_term: 10,
      etf_return_rate: 10.1,
      etf_dividend_yield: 2.8,
      hybrid_property_year: 3,
      hybrid_nab_loan_amount: 75_000,
      max_properties: 5,
      etfs: default_etfs
    }
  end

  def default_etfs
    [
      { name: "IVV", allocation: 40, capital_return: 12.0, dividend_yield: 1.3 },
      { name: "MVW", allocation: 30, capital_return: 8.0, dividend_yield: 3.5 },
      { name: "VAP", allocation: 30, capital_return: 6.5, dividend_yield: 4.0 },
      { name: "",    allocation: 0,  capital_return: 0.0, dividend_yield: 0.0 }
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
