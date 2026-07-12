module InvestmentComparison
  class Calculator
    MILESTONES = [ 5, 10, 15, 20, 25 ].freeze

    def initialize(params)
      @params = params
      @timeframe = params[:timeframe].to_i
    end

    def call
      scenarios = [
        PropertyScenario.new(@params).calculate,
        NabEbScenario.new(@params).calculate,
        HybridScenario.new(@params).calculate,
        MultiPropertyScenario.new(@params).calculate
      ]

      {
        scenarios: scenarios,
        chart_data: build_chart_data(scenarios),
        milestones: build_milestones(scenarios)
      }
    end

    private

    def build_chart_data(scenarios)
      scenarios.map do |scenario|
        {
          name: scenario[:name],
          color: scenario[:color],
          data: scenario[:yearly_data].each_with_object({}) do |snapshot, hash|
            hash["Year #{snapshot[:year]}"] = snapshot[:equity]
          end
        }
      end
    end

    def build_milestones(scenarios)
      active_milestones = MILESTONES.select { |m| m <= @timeframe }
      active_milestones.map do |year|
        milestone = { year: year, scenarios: [] }
        scenarios.each do |scenario|
          data = scenario[:yearly_data].find { |s| s[:year] == year }
          next unless data
          milestone[:scenarios] << {
            name: scenario[:name],
            color: scenario[:color],
            equity: data[:equity],
            asset_value: data[:asset_value],
            loan_balance: data[:loan_balance],
            cumulative_invested: data[:cumulative_invested]
          }
        end
        milestone
      end
    end
  end
end
