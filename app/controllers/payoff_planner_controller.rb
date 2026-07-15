class PayoffPlannerController < ApplicationController
  DEFAULT_INVESTMENT_RETURN = 7.0

  def index
    @liabilities = current_user.user_liabilities.order(interest_rate: :desc)
    @monthly_budget = params.fetch(:monthly_budget) {
      ((current_user.monthly_budget_surplus_cents || 50_000) / 100.0).round
    }.to_f
    @monthly_budget = @monthly_budget.to_i if (@monthly_budget % 1).zero?
    @investment_return = params.fetch(:investment_return, DEFAULT_INVESTMENT_RETURN).to_f

    return if @liabilities.empty?

    budget_cents = (@monthly_budget * 100).round
    @avalanche = DebtPayoff::Simulator.new(liabilities: @liabilities,
                                           monthly_budget_cents: budget_cents,
                                           strategy: :avalanche).call
    @snowball = DebtPayoff::Simulator.new(liabilities: @liabilities,
                                          monthly_budget_cents: budget_cents,
                                          strategy: :snowball).call

    @highest_rate_debt = @liabilities.first
    @interest_saved_cents = @snowball.total_interest_cents - @avalanche.total_interest_cents
  end
end
