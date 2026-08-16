# Turns Up Bank transaction history into proposed budget amounts: settled
# transactions over a lookback window, internal transfers dropped, expenses
# grouped by Up category onto the budget template rows, credits proposed as
# income, everything averaged to a monthly figure in integer cents.
module UpBank
  class BudgetImporter
    INCOME_ROW = { section: "income", name: "Income 1 (Post Tax)" }.freeze
    SAMPLE_LIMIT = 3

    # Up child category id => budget template row. Some Up categories are
    # broader than the template (rent-and-mortgage covers both; utilities
    # doesn't split gas/water from electricity) — the preview shows the
    # mapping so the user can uncheck anything that lands oddly.
    CATEGORY_MAP = {
      "groceries"                          => { section: "everyday", name: "Groceries" },
      "fuel"                               => { section: "everyday", name: "Petrol" },
      "restaurants-and-cafes"              => { section: "everyday", name: "Restaurants & Take Aways" },
      "takeaway"                           => { section: "everyday", name: "Restaurants & Take Aways" },
      "booze"                              => { section: "everyday", name: "Alcohol, Cigarettes, Gambling Etc" },
      "clothing-and-accessories"           => { section: "everyday", name: "Clothes & Shoes" },
      "gifts-and-charity"                  => { section: "everyday", name: "Gifts" },
      "pets"                               => { section: "everyday", name: "Pet Food" },
      "news-magazines-and-books"           => { section: "everyday", name: "Newspapers, magazines, books etc." },
      "hobbies"                            => { section: "everyday", name: "Sports & hobbies" },
      "games-and-software"                 => { section: "everyday", name: "Sports & hobbies" },
      "events-and-gigs"                    => { section: "everyday", name: "Movies, concerts, bars etc." },
      "pubs-and-bars"                      => { section: "everyday", name: "Movies, concerts, bars etc." },
      "rent-and-mortgage"                  => { section: "bills", name: "Rent" },
      "utilities"                          => { section: "bills", name: "Electricity" },
      "internet"                           => { section: "bills", name: "Internet" },
      "mobile-phone"                       => { section: "bills", name: "Mobile phone/s" },
      "home-insurance-and-rates"           => { section: "bills", name: "Home & Contents Insurance" },
      "home-maintenance-and-improvements"  => { section: "bills", name: "Home Maintenance" },
      "homeware-and-appliances"            => { section: "bills", name: "Household Purchases (appliances, furniture)" },
      "car-insurance-and-maintenance"      => { section: "bills", name: "Car & Vehicle Insurances" },
      "car-repayments"                     => { section: "bills", name: "Car Loan Repayments" },
      "personal-loan-repayments"           => { section: "bills", name: "Personal Loan Repayments" },
      "health-and-medical"                 => { section: "bills", name: "Medical (doctor, dentist etc.)" },
      "fitness-and-wellbeing"              => { section: "bills", name: "Gym" },
      "hair-and-beauty"                    => { section: "bills", name: "Hair Care & Beauty" },
      "education-and-student-loans"        => { section: "bills", name: "School Fees" },
      "holidays-and-travel"                => { section: "bills", name: "Holidays" },
      "tv-and-music"                       => { section: "bills", name: "Pay TV" },
      "public-transport"                   => { section: "bills", name: "Other (Public Transport)" },
      "taxis-and-share-cars"               => { section: "bills", name: "Other (Public Transport)" },
      "toll-roads"                         => { section: "bills", name: "Toll Road" },
      "life-admin"                         => { section: "bills", name: "Other" }
    }.freeze

    SECTION_ORDER = BudgetItem::SECTIONS.keys.each_with_index.to_h.freeze

    def initialize(user:, client: UpBank::Client.new, lookback_months: 12)
      @user = user
      @client = client
      @lookback_months = lookback_months
    end

    def call
      income_cents = 0
      income_count = 0
      income_samples = []
      groups = Hash.new { |h, k| h[k] = { cents: 0, count: 0, samples: [], unmapped: false } }

      @client.transactions(since: @lookback_months.months.ago).each do |tx|
        next if transfer?(tx)

        cents = tx.dig("attributes", "amount", "valueInBaseUnits").to_i
        category = tx.dig("relationships", "category", "data", "id")

        if cents.positive? && category.nil?
          income_cents += cents
          income_count += 1
          add_sample(income_samples, tx)
        else
          # Debits count as spending; categorised credits (refunds) net off.
          group = groups[target_row(category)]
          group[:cents] -= cents
          group[:count] += 1
          group[:unmapped] = true unless CATEGORY_MAP.key?(category)
          add_sample(group[:samples], tx) if cents.negative?
        end
      end

      proposals = groups.filter_map do |row, group|
        next unless group[:cents].positive?

        build_proposal(row, monthly(group[:cents]), group[:count], group[:samples], group[:unmapped])
      end
      if income_cents.positive?
        proposals << build_proposal(INCOME_ROW, monthly(income_cents), income_count, income_samples, false)
      end

      proposals.sort_by { |p| [SECTION_ORDER.fetch(p.section, 99), p.name] }
    end

    private

    def transfer?(tx)
      tx.dig("relationships", "transferAccount", "data").present?
    end

    def target_row(category)
      return CATEGORY_MAP[category] if CATEGORY_MAP.key?(category)
      return { section: "everyday", name: "Uncategorised (Up)" } if category.nil?

      { section: "everyday", name: "#{category.titleize} (Up)" }
    end

    def monthly(cents)
      (cents / @lookback_months.to_f).round
    end

    def add_sample(samples, tx)
      description = tx.dig("attributes", "description").to_s
      return if description.blank? || samples.include?(description) || samples.size >= SAMPLE_LIMIT

      samples << description
    end

    def build_proposal(row, proposed_cents, count, samples, unmapped)
      current = existing_items[[row[:section], row[:name]]]
      Proposal.new(
        section: row[:section],
        name: row[:name],
        current_amount_cents: current&.amount_cents,
        current_frequency: current&.frequency,
        current_monthly_cents: current && (current.yearly_cents / 12.0).round,
        proposed_monthly_cents: proposed_cents,
        transaction_count: count,
        sample_descriptions: samples,
        unmapped: unmapped
      )
    end

    def existing_items
      @existing_items ||= @user.budget_items.index_by { |item| [item.section, item.name] }
    end
  end
end
