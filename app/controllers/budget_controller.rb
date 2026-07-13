class BudgetController < ApplicationController
  before_action :require_login

  # GET /budget
  def index
    BudgetItem.bootstrap_for(current_user)
    @sections = BudgetItem::SECTIONS.keys.index_with do |section|
      current_user.budget_items.in_section(section)
    end
  end

  private

  def require_login
    redirect_to login_path, alert: "Please log in first." unless user_signed_in?
  end
end
