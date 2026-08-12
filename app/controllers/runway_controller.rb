class RunwayController < ApplicationController
  # GET /runway
  def index
    assets = current_user.user_assets.includes(:asset_contributions, :asset_valuations).to_a
    @liquid_assets_cents = assets.select(&:market_asset?).sum(&:current_value_cents)
    @other_assets_cents = assets.reject(&:market_asset?).sum(&:current_value_cents)
    @liabilities_cents = current_user.user_liabilities.sum(:amount_cents)
    @pool_cents = @liquid_assets_cents - @liabilities_cents

    @budget_monthly_spend_cents = budget_monthly_spend_cents
    @monthly_spend = params.fetch(:monthly_spend) { (@budget_monthly_spend_cents / 100.0).round }.to_f
    @monthly_spend = @monthly_spend.to_i if (@monthly_spend % 1).zero?
    @annual_growth = params.fetch(:annual_growth, 0).to_f
    @monthly_surplus_cents = current_user.monthly_budget_surplus_cents

    return if @monthly_spend <= 0

    @result = Runway::Simulator.new(starting_pool_cents: @pool_cents,
                                    monthly_spend_cents: (@monthly_spend * 100).round,
                                    annual_growth_pct: @annual_growth).call
    @chart_data = @result.monthly_totals.transform_keys { |m| (Date.today >> m).strftime("%b %Y") }
                         .transform_values { |cents| (cents / 100.0).round(2) }
  end

  private

  # Bills + everyday spending from the budget, normalised to a month.
  def budget_monthly_spend_cents
    (current_user.budget_items.where(section: %w[bills everyday]).sum(&:yearly_cents) / 12.0).round
  end
end
