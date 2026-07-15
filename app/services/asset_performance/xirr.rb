# Money-weighted (internal) rate of return for dated cashflows.
# Cashflows are [[Date, cents], ...] where money in is negative (you paid it)
# and the terminal value is positive. Returns the annualised rate as a float
# (0.10 == 10% p.a.), or nil when a rate can't be meaningfully computed.
module AssetPerformance
  class Xirr
    MIN_RATE = -0.9999
    MAX_RATE = 10.0
    TOLERANCE = 1e-7
    MIN_SPAN_DAYS = 30

    def initialize(cashflows)
      @cashflows = cashflows.sort_by(&:first)
    end

    def call
      return nil if @cashflows.size < 2
      return nil unless @cashflows.any? { |_, amount| amount.negative? } &&
                        @cashflows.any? { |_, amount| amount.positive? }
      return nil if (@cashflows.last.first - @cashflows.first.first).to_i < MIN_SPAN_DAYS

      solve_bisection
    end

    private

    def npv(rate)
      epoch = @cashflows.first.first
      @cashflows.sum do |date, amount|
        years = (date - epoch).to_f / 365.25
        amount / ((1.0 + rate)**years)
      end
    end

    def solve_bisection
      low = MIN_RATE
      high = MAX_RATE
      return nil if npv(low) * npv(high) > 0

      100.times do
        mid = (low + high) / 2.0
        value = npv(mid)
        return mid if value.abs < TOLERANCE

        if npv(low) * value < 0
          high = mid
        else
          low = mid
        end
      end

      (low + high) / 2.0
    end
  end
end
