class BudgetItem < ApplicationRecord
  belongs_to :user

  # Occurrences per year for each pay/billing frequency.
  FREQUENCIES = {
    "weekly"      => 52,
    "fortnightly" => 26,
    "monthly"     => 12,
    "quarterly"   => 4,
    "annually"    => 1
  }.freeze

  SECTIONS = {
    "income"   => "Income (Net)",
    "bills"    => "Bills' Account",
    "everyday" => "Everyday Account"
  }.freeze

  DEFAULT_TEMPLATE = {
    "income" => [
      "Income 1 (Post Tax)", "Income 2", "Other Income 1", "Other Income 2"
    ],
    "bills" => [
      "Mortgage Repayments", "Rent", "Body Corporate Fees", "Personal Loan Repayments",
      "Car Loan Repayments", "Credit Card Repayments", "Bank Fees", "Home Maintenance",
      "Rates", "Water", "Electricity", "Gas", "Gardening & Pool Maintenance",
      "Home Services (cleaning etc)", "Pest Control", "Mobile phone/s", "Internet",
      "Car & Vehicle Registrations", "Licence & Fines", "Personal Insurances",
      "Private Health Insurance", "Home & Contents Insurance", "Car & Vehicle Insurances",
      "Medical (doctor, dentist etc.)", "Child Care", "School Fees", "Text Books",
      "Investments", "Superannuation Contributions", "Tax Deductible Expenses",
      "Parties, Anniversaries, Christmas etc.", "Holidays", "Pay TV", "Vet",
      "Hair Care & Beauty", "Household Purchases (appliances, furniture)",
      "Roadside Assist", "Toll Road", "Gym", "Other (Public Transport)", "Other"
    ],
    "everyday" => [
      "Groceries", "Petrol", "Gifts", "Clothes & Shoes", "Pocket Money (children)",
      "Pet Food", "Dry Cleaning", "Pharmacy", "Parking Fees", "Restaurants & Take Aways",
      "Movies, concerts, bars etc.", "Sports & hobbies",
      "Newspapers, magazines, books etc.", "Musical Instruments and/or Lessons",
      "Alcohol, Cigarettes, Gambling Etc"
    ]
  }.freeze

  validates :name, presence: true, length: { maximum: 100 }
  validates :name, uniqueness: { scope: [:user_id, :section] }
  validates :section, inclusion: { in: SECTIONS.keys }
  validates :frequency, inclusion: { in: FREQUENCIES.keys }
  validates :amount_cents, numericality: { greater_than_or_equal_to: 0, only_integer: true }

  scope :in_section, ->(section) { where(section: section).order(:position, :id) }

  # Create the standard template rows on a user's first visit. Never re-runs
  # once the user has any items, so deleted template rows stay deleted.
  def self.bootstrap_for(user)
    return if user.budget_items.exists?

    DEFAULT_TEMPLATE.each do |section, names|
      names.each_with_index do |name, index|
        user.budget_items.create!(section: section, name: name, position: index)
      end
    end
  end

  # Amount exposed in dollars for forms.
  def amount
    amount_cents / 100.0
  end

  def amount=(dollars)
    self.amount_cents = (dollars.to_f * 100).round
  end

  def yearly_cents
    amount_cents * FREQUENCIES.fetch(frequency)
  end

  # Value of this item normalised to another frequency, in dollars.
  def amount_per(target_frequency)
    yearly_cents / (FREQUENCIES.fetch(target_frequency) * 100.0)
  end
end
