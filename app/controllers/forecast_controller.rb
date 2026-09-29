class ForecastController < ApplicationController
  DEFAULTS = { current_age: 30, retirement_age: 65, horizon_years: 40,
               annual_growth: 7.0, inflation: 2.5 }.freeze

  # GET /forecast
  def index
    load_inputs
    remember_settings if params[:current_age].present?

    assets = current_user.user_assets.includes(:asset_contributions, :asset_valuations).to_a
    liabilities = current_user.user_liabilities.to_a
    @investments_cents = assets.select(&:market_asset?).sum(&:current_value_cents)
    @other_assets_cents = assets.reject(&:market_asset?).sum(&:current_value_cents)
    @liabilities_cents = liabilities.sum(&:amount_cents)

    inputs = { assets: assets, liabilities: liabilities, current_age: @current_age,
               horizon_years: @horizon_years, annual_growth_pct: @annual_growth,
               inflation_pct: @inflation,
               monthly_contribution_cents: (@monthly_contribution.to_f * 100).round,
               retirement_spend_cents: (@retirement_spend.to_f * 100).round }
    @result = NetWorth::Projection.new(retirement_age: @retirement_age, **inputs).call
    @earliest_retirement_age = NetWorth::Projection.earliest_retirement_age(**inputs)
    @end_age = @current_age + @horizon_years
    @chart_data = chart_series
  end

  private

  # Precedence for every input: typed params > saved settings > default.
  def load_inputs
    user = current_user
    @current_age = int_param(:current_age) || saved_age(user) || DEFAULTS[:current_age]
    @retirement_age = int_param(:retirement_age) || user.forecast_retirement_age ||
                      DEFAULTS[:retirement_age]
    @horizon_years = (int_param(:horizon_years) || user.forecast_horizon_years ||
                      DEFAULTS[:horizon_years]).clamp(1, NetWorth::Projection::MAX_YEARS)
    @annual_growth = float_param(:annual_growth) || user.forecast_annual_growth&.to_f ||
                     DEFAULTS[:annual_growth]
    @inflation = float_param(:inflation) || user.forecast_inflation&.to_f || DEFAULTS[:inflation]
    @monthly_contribution = float_param(:monthly_contribution) ||
                            from_cents(user.forecast_monthly_contribution_cents) ||
                            from_cents([user.monthly_budget_surplus_cents || 0, 0].max)
    @retirement_spend = float_param(:retirement_spend) ||
                        from_cents(user.forecast_retirement_spend_cents) ||
                        from_cents(user.runway_monthly_spend_cents) ||
                        from_cents(budget_monthly_spend_cents)

    %i[@annual_growth @inflation @monthly_contribution @retirement_spend].each do |ivar|
      value = instance_variable_get(ivar)
      instance_variable_set(ivar, value.to_i) if value && (value % 1).zero?
    end
  end

  def saved_age(user)
    user.forecast_birth_year && Date.today.year - user.forecast_birth_year
  end

  def int_param(key)
    params[key].presence&.to_i
  end

  def float_param(key)
    params[key].presence&.to_f
  end

  def from_cents(cents)
    cents && cents / 100.0
  end

  # Bills + everyday spending from the budget, normalised to a month.
  def budget_monthly_spend_cents
    (current_user.budget_items.where(section: %w[bills everyday]).sum(&:yearly_cents) / 12.0).round
  end

  # Remember the last recalculated inputs so the page reopens with them. Age is
  # stored as a birth year so it keeps ticking over without being re-entered.
  def remember_settings
    current_user.update!(
      forecast_birth_year: Date.today.year - @current_age,
      forecast_retirement_age: @retirement_age,
      forecast_horizon_years: @horizon_years,
      forecast_annual_growth: @annual_growth,
      forecast_inflation: @inflation,
      forecast_monthly_contribution_cents: (@monthly_contribution.to_f * 100).round,
      forecast_retirement_spend_cents: (@retirement_spend.to_f * 100).round
    )
  end

  # Net worth is split into a working and a retired series so the chart shows
  # where retirement starts; the two share the retirement-year point.
  def chart_series
    yearly = @result.yearly
    label = ->(row) { row.date.year.to_s }
    dollars = ->(cents) { (cents / 100.0).round(2) }
    retirement_year = yearly.find(&:retired)&.date&.year

    [
      { name: "Net worth (working)", color: "#3b82f6",
        data: yearly.to_h { |r| [label.(r), r.retired && r.date.year != retirement_year ? nil : dollars.(r.net_worth_cents)] } },
      { name: "Net worth (retired)", color: "#8b5cf6",
        data: yearly.to_h { |r| [label.(r), r.retired ? dollars.(r.net_worth_cents) : nil] } },
      { name: "Investments", color: "#10b981",
        data: yearly.to_h { |r| [label.(r), dollars.(r.investments_cents)] } },
      { name: "Debts", color: "#ef4444",
        data: yearly.to_h { |r| [label.(r), dollars.(r.liabilities_cents)] } }
    ]
  end
end
