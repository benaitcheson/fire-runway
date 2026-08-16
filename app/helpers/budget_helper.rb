module BudgetHelper
  # Total of a set of budget items normalised to a frequency, in dollars.
  def budget_total(items, frequency)
    items.sum(&:yearly_cents) / (BudgetItem::FREQUENCIES.fetch(frequency) * 100.0)
  end

  def budget_amount(dollars)
    number_with_precision(dollars, precision: 2, delimiter: ",")
  end

  def up_bank_configured?
    ENV["UP_API_TOKEN"].present?
  end
end
