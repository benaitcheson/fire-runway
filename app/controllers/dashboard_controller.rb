class DashboardController < ApplicationController
  def index
    @user_assets = current_user.user_assets
    @user_liabilities = 1000

    @net_worth_data = @user_assets.sum(:purchase_price_cents) - @user_liabilities
  end
end
