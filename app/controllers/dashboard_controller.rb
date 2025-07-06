class DashboardController < ApplicationController
  def index
    @user_assets = current_user.user_assets
    @user_liabilities = current_user.user_liabilities

    @net_worth_data = calculate_net_worth_data
  end

  private

  def calculate_net_worth_data
    user_assets_total = current_user.user_assets.sum(&:current_value_cents)
    user_assets_purchase_total = current_user.user_assets.sum(:purchase_price_cents)
    user_liabilities_total = current_user.user_liabilities.sum(:amount_cents)

    net_worth = user_assets_total - user_liabilities_total

    {
      user_assets_total: user_assets_total,
      user_assets_purchase_total: user_assets_purchase_total,
      user_liabilities_total: user_liabilities_total,
      net_worth: net_worth,
      total_depreciation: user_assets_purchase_total - user_assets_total
    }
  end
end
