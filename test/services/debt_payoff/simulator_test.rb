require "test_helper"

class DebtPayoff::SimulatorTest < ActiveSupport::TestCase
  def build_debt(name, balance_dollars, rate, minimum_dollars = 0)
    UserLiability.new(item_name: name, amount_cents: balance_dollars * 100,
                      interest_rate: rate, minimum_monthly_payment_cents: minimum_dollars * 100)
  end

  def simulate(debts, budget_dollars, strategy)
    DebtPayoff::Simulator.new(liabilities: debts, monthly_budget_cents: budget_dollars * 100,
                              strategy: strategy).call
  end

  test "single debt pays off in the expected time" do
    # $1,200 at 0% with $100/month = exactly 12 months
    result = simulate([build_debt("Loan", 1_200, 0)], 100, :avalanche)

    assert_equal 12, result.months
    assert_equal 0, result.total_interest_cents
    assert_equal [{ name: "Loan", month: 12 }], result.payoff_order
    assert_not result.insufficient_budget
  end

  test "avalanche targets the highest rate first" do
    debts = [build_debt("Big cheap", 10_000, 3), build_debt("Small dear", 2_000, 20)]
    result = simulate(debts, 500, :avalanche)

    assert_equal "Small dear", result.payoff_order.first[:name]
  end

  test "snowball targets the smallest balance first" do
    debts = [build_debt("Big dear", 10_000, 20), build_debt("Small cheap", 2_000, 3)]
    result = simulate(debts, 500, :snowball)

    assert_equal "Small cheap", result.payoff_order.first[:name]
  end

  test "avalanche never pays more interest than snowball" do
    debts = [
      build_debt("Credit card", 5_000, 20, 50),
      build_debt("Car loan", 15_000, 8, 300),
      build_debt("HECS", 30_000, 4)
    ]
    avalanche = simulate(debts.map(&:dup), 1_000, :avalanche)
    snowball = simulate(debts.map(&:dup), 1_000, :snowball)

    assert_operator avalanche.total_interest_cents, :<=, snowball.total_interest_cents
    assert_operator avalanche.months, :<=, snowball.months
  end

  test "flags a budget that cannot cover interest" do
    # $10,000 at 60% accrues ~$500/month; $100 budget can never win
    result = simulate([build_debt("Loan shark", 10_000, 60)], 100, :avalanche)

    assert result.insufficient_budget
    assert_nil result.months
  end

  test "minimum payments are honoured on non-target debts" do
    debts = [build_debt("Target", 1_000, 20), build_debt("Background", 12_000, 5, 100)]
    result = simulate(debts, 300, :avalanche)

    # Background debt must shrink from month one despite not being the target.
    assert_not result.insufficient_budget
    assert result.payoff_order.map { |p| p[:name] }.include?("Background")
  end

  test "monthly totals start at the combined balance and reach zero" do
    debts = [build_debt("A", 1_000, 10), build_debt("B", 2_000, 5)]
    result = simulate(debts, 400, :avalanche)

    assert_equal 300_000, result.monthly_totals[0]
    assert_equal 0, result.monthly_totals[result.months]
  end

  test "rejects unknown strategies" do
    assert_raises(ArgumentError) do
      simulate([build_debt("A", 100, 1)], 100, :yolo)
    end
  end
end
