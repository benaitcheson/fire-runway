class BudgetController < ApplicationController
  # GET /budget
  def index
    BudgetItem.bootstrap_for(current_user)
    @sections = BudgetItem::SECTIONS.keys.index_with do |section|
      current_user.budget_items.in_section(section)
    end
  end
end
