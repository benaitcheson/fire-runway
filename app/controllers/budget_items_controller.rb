class BudgetItemsController < ApplicationController
  before_action :require_login

  # POST /budget_items
  def create
    item = current_user.budget_items.build(budget_item_params)
    item.position = (current_user.budget_items.in_section(item.section).maximum(:position) || 0) + 1

    if item.save
      redirect_to budget_path
    else
      redirect_to budget_path, alert: item.errors.full_messages.to_sentence
    end
  end

  # PATCH /budget_items/1
  def update
    item = current_user.budget_items.find(params[:id])

    if item.update(budget_item_params)
      redirect_to budget_path
    else
      redirect_to budget_path, alert: item.errors.full_messages.to_sentence
    end
  end

  # DELETE /budget_items/1
  def destroy
    current_user.budget_items.find(params[:id]).destroy
    redirect_to budget_path
  end

  private

  def require_login
    redirect_to login_path, alert: "Please log in first." unless user_signed_in?
  end

  def budget_item_params
    params.require(:budget_item).permit(:name, :amount, :frequency, :section)
  end
end
