# Rolls today's balance sheet forward month by month to see what net worth
# looks like in 20, 30, 40 years — and what happens once the pay cheques stop.
#
# Two phases:
#   working  — every month the contribution goes into the investment pool
#   retired  — every month the retirement spend comes out of it
#
# Market assets (shares, super, cash, property marked to market) form the
# investment pool and compound at the growth rate. Depreciating assets follow
# their own depreciation curves and are never spent. Debts accrue interest and
# pay their minimum repayment each month; a repayment is assumed to already sit
# inside the budget, so when a debt clears that money rolls into contributions
# (while working) or reduces the spend (once retired).
#
# Everything is in today's dollars: the growth rate is deflated by inflation
# and contributions/spend stay flat, so a figure 30 years out is comparable
# with the numbers on the dashboard today.
module NetWorth
  class Projection
    MAX_YEARS = 60

    Row = Struct.new(:month, :age, :date, :investments_cents, :other_assets_cents,
                     :liabilities_cents, :net_worth_cents, :retired, keyword_init: true)

    Result = Struct.new(:rows, :retirement_age, :horizon_years, :depleted_at_age,
                        :debt_free_at_age, keyword_init: true) do
      def at_retirement = rows.find(&:retired) || rows.last
      def final = rows.last
      def peak = rows.max_by(&:net_worth_cents)
      def depleted? = !depleted_at_age.nil?

      # One row per year (month 0, 12, 24 ...), for charts and tables.
      def yearly = rows.select { |r| (r.month % 12).zero? }
    end

    def initialize(assets:, liabilities:, current_age:, retirement_age:, horizon_years:,
                   annual_growth_pct:, inflation_pct: 0.0, monthly_contribution_cents: 0,
                   retirement_spend_cents: 0, today: Date.today)
      @assets = assets.to_a
      @liabilities = liabilities.to_a
      @current_age = current_age.to_i
      @retirement_age = retirement_age.to_i
      @horizon_years = horizon_years.to_i.clamp(1, MAX_YEARS)
      @monthly_rate = real_monthly_rate(annual_growth_pct.to_f, inflation_pct.to_f)
      @contribution = monthly_contribution_cents.to_i
      @spend = retirement_spend_cents.to_i
      @today = today
    end

    def call
      pool = @assets.select(&:market_asset?).sum(&:current_value_cents)
      debts = @liabilities.map do |l|
        { balance: l.amount_cents, rate: l.interest_rate.to_f, minimum: l.minimum_monthly_payment_cents }
      end
      contribution = @contribution
      spend = @spend
      depleted_at_age = nil
      debt_free_at_age = nil
      rows = []

      # Each row is a point in time: month 0 is today, month 12 is a year from
      # now. The step into a row plays out the month just lived, at the age the
      # person was during it, so the retirement-birthday row still shows the
      # full working balance.
      (0..(@horizon_years * 12)).each do |month|
        age = @current_age + month / 12
        retired = age >= @retirement_age

        if month.positive?
          retired_during_month = @current_age + (month - 1) / 12 >= @retirement_age
          pool += (pool * @monthly_rate).round
          freed = step_debts(debts)
          # A repayment freed by a debt clearing this month kicks in next month.
          if retired_during_month
            pool -= spend
            spend = [spend - freed, 0].max
          else
            pool += contribution
            contribution += freed
          end
          if pool <= 0 && depleted_at_age.nil? && retired_during_month && spend.positive?
            depleted_at_age = age
          end
          pool = 0 if pool.negative?
        end

        date = @today >> month
        liabilities = debts.sum { |d| d[:balance] }
        debt_free_at_age ||= age if liabilities.zero? && @liabilities.any?
        other = @assets.reject(&:market_asset?).sum { |a| depreciated_value(a, date) }

        rows << Row.new(month: month, age: age, date: date, investments_cents: pool,
                        other_assets_cents: other, liabilities_cents: liabilities,
                        net_worth_cents: pool + other - liabilities, retired: retired)
      end

      Result.new(rows: rows, retirement_age: @retirement_age, horizon_years: @horizon_years,
                 depleted_at_age: depleted_at_age, debt_free_at_age: debt_free_at_age)
    end

    # The youngest retirement age (from now until the end of the horizon) at
    # which the investment pool never runs dry. nil when even working to the
    # end of the horizon doesn't get there.
    def self.earliest_retirement_age(current_age:, horizon_years:, **inputs)
      end_age = current_age.to_i + horizon_years.to_i
      (current_age.to_i...end_age).find do |age|
        !new(current_age: current_age, horizon_years: horizon_years,
             retirement_age: age, **inputs).call.depleted?
      end
    end

    private

    # Annual nominal growth deflated by inflation, then converted to a monthly
    # compounding rate so the series is in today's dollars.
    def real_monthly_rate(growth_pct, inflation_pct)
      real_annual = (1 + growth_pct / 100.0) / (1 + inflation_pct / 100.0)
      real_annual**(1 / 12.0) - 1
    end

    # Accrue a month of interest and pay the minimum on every open debt.
    # Returns the repayments freed up by debts that cleared this month. A debt
    # with no minimum repayment is held flat — we assume its interest is being
    # serviced somewhere outside this model.
    def step_debts(debts)
      freed = 0
      debts.each do |debt|
        next if debt[:balance].zero? || debt[:minimum].zero?

        debt[:balance] += (debt[:balance] * debt[:rate] / 100.0 / 12.0).round
        debt[:balance] = [debt[:balance] - debt[:minimum], 0].max
        freed += debt[:minimum] if debt[:balance].zero?
      end
      freed
    end

    def depreciated_value(asset, date)
      return 0 if asset.purchase_date.nil? || date < asset.purchase_date

      asset.current_value_at_year((date - asset.purchase_date).to_f / 365.25)
    end
  end
end
