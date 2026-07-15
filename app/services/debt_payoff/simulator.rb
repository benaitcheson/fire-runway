# Simulates paying off a set of debts month by month with a fixed monthly
# budget. Interest accrues monthly (annual rate / 12), minimum payments are
# made on every debt, and the remainder goes to one target debt at a time,
# ordered by strategy:
#   :avalanche — highest interest rate first (mathematically optimal)
#   :snowball  — smallest balance first (fastest wins for motivation)
# As each debt clears, its minimum payment rolls into the pool.
module DebtPayoff
  class Simulator
    MAX_MONTHS = 600

    Result = Struct.new(:strategy, :months, :total_interest_cents, :payoff_order,
                        :monthly_totals, :insufficient_budget, keyword_init: true) do
      def debt_free_date = months ? Date.today >> months : nil
    end

    def initialize(liabilities:, monthly_budget_cents:, strategy:)
      @debts = liabilities.map do |l|
        { name: l.item_name, balance: l.amount_cents, rate: l.interest_rate.to_f,
          minimum: l.minimum_monthly_payment_cents }
      end
      @budget = monthly_budget_cents
      @strategy = strategy.to_sym
    end

    def call
      total_interest = 0
      payoff_order = []
      monthly_totals = { 0 => total_balance }

      MAX_MONTHS.times do |i|
        month = i + 1
        start_total = total_balance

        accrued = accrue_interest
        total_interest += accrued
        pay_month(payoff_order, month)

        monthly_totals[month] = total_balance

        if debt_free?
          return Result.new(strategy: @strategy, months: month,
                            total_interest_cents: total_interest,
                            payoff_order: payoff_order, monthly_totals: monthly_totals,
                            insufficient_budget: false)
        end

        # Budget doesn't even cover interest — balances will grow forever.
        if total_balance >= start_total
          return Result.new(strategy: @strategy, months: nil,
                            total_interest_cents: total_interest,
                            payoff_order: payoff_order, monthly_totals: monthly_totals,
                            insufficient_budget: true)
        end
      end

      Result.new(strategy: @strategy, months: nil, total_interest_cents: total_interest,
                 payoff_order: payoff_order, monthly_totals: monthly_totals,
                 insufficient_budget: true)
    end

    private

    def total_balance = @debts.sum { |d| d[:balance] }
    def debt_free? = @debts.all? { |d| d[:balance].zero? }

    def accrue_interest
      @debts.sum do |debt|
        next 0 if debt[:balance].zero?

        interest = (debt[:balance] * debt[:rate] / 100.0 / 12.0).round
        debt[:balance] += interest
        interest
      end
    end

    def pay_month(payoff_order, month)
      budget = @budget

      # Minimums first, on every open debt.
      @debts.each do |debt|
        next if debt[:balance].zero?

        payment = [debt[:minimum], debt[:balance], budget].min
        debt[:balance] -= payment
        budget -= payment
      end

      # Remainder to one debt at a time in strategy order.
      prioritised.each do |debt|
        break if budget.zero?
        next if debt[:balance].zero?

        payment = [debt[:balance], budget].min
        debt[:balance] -= payment
        budget -= payment
      end

      @debts.each do |debt|
        if debt[:balance].zero? && payoff_order.none? { |p| p[:name] == debt[:name] }
          payoff_order << { name: debt[:name], month: month }
        end
      end
    end

    def prioritised
      case @strategy
      when :avalanche then @debts.sort_by { |d| [-d[:rate], d[:balance]] }
      when :snowball  then @debts.sort_by { |d| [d[:balance], -d[:rate]] }
      else raise ArgumentError, "Unknown strategy: #{@strategy}"
      end
    end
  end
end
