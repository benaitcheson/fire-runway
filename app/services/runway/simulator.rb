# Simulates how long a pool of money lasts at a fixed monthly spend, month by
# month. Growth compounds monthly (annual rate converted to its monthly
# equivalent) on whatever remains, then the month's spend comes out. The pool
# is "indefinite" when growth covers the spend before the horizon runs out.
module Runway
  class Simulator
    MAX_MONTHS = 1200 # 100 years — treat anything longer as indefinite
    CHART_MONTHS = 360 # cap the plotted series at 30 years

    Result = Struct.new(:months, :monthly_totals, :indefinite, keyword_init: true) do
      def depletion_date = months&.positive? ? Date.today >> months : nil

      def in_words
        return "indefinitely" if indefinite
        return "no time at all" if months.nil? || months <= 0

        years, remainder = months.divmod(12)
        parts = []
        parts << "#{years} #{"year".pluralize(years)}" if years.positive?
        parts << "#{remainder} #{"month".pluralize(remainder)}" if remainder.positive?
        parts.join(", ")
      end
    end

    def initialize(starting_pool_cents:, monthly_spend_cents:, annual_growth_pct: 0.0)
      @pool = starting_pool_cents
      @spend = monthly_spend_cents
      @monthly_rate = ((1 + annual_growth_pct / 100.0)**(1 / 12.0)) - 1
    end

    def call
      return Result.new(months: 0, monthly_totals: { 0 => 0 }, indefinite: false) if @pool <= 0
      return indefinite_result if @spend <= 0

      totals = { 0 => @pool }
      pool = @pool

      MAX_MONTHS.times do |i|
        pool = pool + (pool * @monthly_rate).round - @spend
        totals[i + 1] = [pool, 0].max if i + 1 <= CHART_MONTHS
        return Result.new(months: i + 1, monthly_totals: totals, indefinite: false) if pool <= 0
      end

      indefinite_result(totals)
    end

    private

    def indefinite_result(totals = nil)
      totals ||= (0..CHART_MONTHS).index_with do |i|
        # spend is zero here, so the pool only ever grows
        (@pool * (1 + @monthly_rate)**i).round
      end
      Result.new(months: nil, monthly_totals: totals, indefinite: true)
    end
  end
end
