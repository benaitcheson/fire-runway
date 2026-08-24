module Tax
  # FY 2025-26 Australian resident tax rules: progressive brackets, LITO,
  # Medicare levy (with the low-income phase-in), Medicare levy surcharge
  # (singles, no dependants), HELP/HECS repayments under the marginal system
  # introduced in 2025-26, and franking credits as a refundable offset.
  #
  # MLS surcharge income and HELP repayment income both ADD BACK net
  # investment losses, so negative gearing lowers income tax but not those
  # two — callers pass the add-back via net_investment_loss.
  class AustralianResident
    FINANCIAL_YEAR = "2025-26".freeze

    # [upper bound, marginal rate]
    BRACKETS = [
      [18_200, 0.0],
      [45_000, 0.16],
      [135_000, 0.30],
      [190_000, 0.37],
      [Float::INFINITY, 0.45]
    ].freeze

    MEDICARE_LEVY_RATE = 0.02
    # Below the threshold no levy; above it the levy phases in at 10c per
    # dollar of excess until it reaches the full 2% of taxable income.
    MEDICARE_LOW_INCOME_THRESHOLD = 28_011
    MEDICARE_PHASE_IN_RATE = 0.10

    # Surcharge tiers for singles with no dependants: [upper bound, rate].
    # Family thresholds are roughly double — not modelled.
    MLS_TIERS = [
      [101_000, 0.0],
      [118_000, 0.01],
      [158_000, 0.0125],
      [Float::INFINITY, 0.015]
    ].freeze

    # HELP/HECS marginal system: nothing below the threshold, 15c per dollar
    # to the second threshold, then 17c per dollar — except above the point
    # where 10% of total repayment income is lower, which applies instead.
    HELP_THRESHOLD = 67_000
    HELP_SECOND_THRESHOLD = 125_000
    HELP_FLAT_THRESHOLD = 179_286
    HELP_LOWER_RATE = 0.15
    HELP_UPPER_RATE = 0.17
    HELP_FLAT_RATE = 0.10

    # Low income tax offset: $700, -5c/$ over $37,500, -1.5c/$ over $45,000.
    LITO_MAX = 700.0
    LITO_FIRST_TAPER = 37_500
    LITO_SECOND_TAPER = 45_000
    LITO_CUTOUT = 66_667

    Assessment = Struct.new(
      :taxable_income, :base_tax, :lito, :medicare_levy,
      :medicare_levy_surcharge, :hecs_repayment, :franking_offset,
      :total_payable, :net_income, :surcharge_income, :repayment_income,
      keyword_init: true
    )

    class << self
      # Full assessment. franking_credits are refundable (total_payable can go
      # negative). net_investment_loss (>= 0) is added back to the income
      # bases used for MLS and HELP.
      def assess(taxable_income:, franking_credits: 0.0, net_investment_loss: 0.0,
                 has_hecs: false, hecs_balance: nil, private_hospital_cover: false)
        income = [taxable_income.to_f, 0.0].max
        base = tax_on(income)
        offset = lito(income)
        income_tax = [base - offset, 0.0].max
        levy = medicare_levy(income)
        income_base = income + net_investment_loss.to_f
        surcharge = mls(income_base, private_hospital_cover: private_hospital_cover)
        hecs = has_hecs ? hecs_repayment(income_base, balance: hecs_balance) : 0.0
        total = income_tax + levy + surcharge + hecs - franking_credits.to_f

        Assessment.new(
          taxable_income: income, base_tax: base, lito: offset,
          medicare_levy: levy, medicare_levy_surcharge: surcharge,
          hecs_repayment: hecs, franking_offset: franking_credits.to_f,
          total_payable: total, net_income: income - total,
          surcharge_income: income_base, repayment_income: income_base
        )
      end

      def tax_on(income)
        tax = 0.0
        lower = 0
        BRACKETS.each do |upper, rate|
          slice = [income, upper].min - lower
          break if slice <= 0
          tax += slice * rate
          lower = upper
        end
        tax
      end

      def lito(income)
        return 0.0 if income >= LITO_CUTOUT

        if income > LITO_SECOND_TAPER
          325.0 - (income - LITO_SECOND_TAPER) * 0.015
        elsif income > LITO_FIRST_TAPER
          LITO_MAX - (income - LITO_FIRST_TAPER) * 0.05
        else
          LITO_MAX
        end
      end

      def medicare_levy(income)
        return 0.0 if income <= MEDICARE_LOW_INCOME_THRESHOLD

        [MEDICARE_PHASE_IN_RATE * (income - MEDICARE_LOW_INCOME_THRESHOLD),
         MEDICARE_LEVY_RATE * income].min
      end

      def mls(surcharge_income, private_hospital_cover: false)
        return 0.0 if private_hospital_cover

        rate = MLS_TIERS.find { |upper, _| surcharge_income <= upper }.last
        surcharge_income * rate
      end

      def hecs_repayment(repayment_income, balance: nil)
        repayment =
          if repayment_income <= HELP_THRESHOLD
            0.0
          elsif repayment_income <= HELP_SECOND_THRESHOLD
            (repayment_income - HELP_THRESHOLD) * HELP_LOWER_RATE
          elsif repayment_income < HELP_FLAT_THRESHOLD
            (HELP_SECOND_THRESHOLD - HELP_THRESHOLD) * HELP_LOWER_RATE +
              (repayment_income - HELP_SECOND_THRESHOLD) * HELP_UPPER_RATE
          else
            repayment_income * HELP_FLAT_RATE
          end
        repayment = [repayment, balance.to_f].min if balance
        [repayment, 0.0].max
      end

      # Marginal bracket rate plus the 2% Medicare levy, as a percentage.
      # Nil below the tax-free threshold (callers apply their own default).
      def marginal_rate(income)
        return nil if income < 18_200

        rate = BRACKETS.find { |upper, _| income < upper }&.last || 0.45
        rate * 100 + 2.0
      end
    end
  end
end
