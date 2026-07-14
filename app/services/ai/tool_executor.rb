# Dispatches AI tool calls to read-only methods scoped to a single user.
# The user is fixed at construction — tool arguments can never widen the scope.
# Every result (including every error) is returned as a JSON string so the
# model loop never sees an exception.
module Ai
  class ToolExecutor
    def initialize(user:)
      @user = user
    end

    def execute(tool_name, args = {})
      unless Ai::Tools.names.include?(tool_name)
        return { error: "Unknown tool: #{tool_name}" }.to_json
      end

      result = public_send(tool_name, args || {})
      result.to_json
    rescue StandardError => e
      Rails.logger.error "AI tool error (#{tool_name}): #{e.class}: #{e.message}"
      { error: "#{e.class}: #{e.message}" }.to_json
    end

    def get_net_worth_summary(_args = {})
      assets = @user.user_assets
      current_value = assets.sum(&:current_value_cents)
      purchase_value = assets.sum(:purchase_price_cents)
      liabilities = @user.user_liabilities.sum(:amount_cents)

      {
        total_assets_current_value: dollars(current_value),
        total_assets_purchase_value: dollars(purchase_value),
        total_depreciation: dollars(purchase_value - current_value),
        total_liabilities: dollars(liabilities),
        net_worth: dollars(current_value - liabilities),
        asset_count: assets.size,
        liability_count: @user.user_liabilities.size
      }
    end

    def list_assets(_args = {})
      assets = @user.user_assets.map do |asset|
        {
          name: asset.item_name,
          purchase_price: dollars(asset.purchase_price_cents),
          current_value: dollars(asset.current_value_cents),
          purchase_date: asset.purchase_date&.iso8601,
          depreciation_method: asset.depreciation_method
        }
      end
      { assets: assets }
    end

    def list_liabilities(_args = {})
      liabilities = @user.user_liabilities.map do |liability|
        { name: liability.item_name, amount: dollars(liability.amount_cents) }
      end
      { liabilities: liabilities }
    end

    def get_asset_depreciation(args = {})
      name = args["name"].to_s.strip
      return { error: "name is required" } if name.blank?

      asset = @user.user_assets.where("item_name ILIKE ?", "%#{UserAsset.sanitize_sql_like(name)}%").first
      return { error: "No asset matching '#{name}'" } unless asset

      projection = (0..[asset.useful_life_years || 5, 10].min).map do |year|
        { year: year, value: dollars(asset.current_value_at_year(year)) }
      end

      {
        name: asset.item_name,
        purchase_price: dollars(asset.purchase_price_cents),
        current_value: dollars(asset.current_value_cents),
        depreciation_method: asset.depreciation_method,
        depreciation_percentage: asset.depreciation_percentage,
        annual_depreciation: dollars(asset.annual_depreciation_cents),
        projected_values: projection
      }
    end

    def get_budget_summary(_args = {})
      sections = BudgetItem::SECTIONS.keys.index_with do |section|
        @user.budget_items.in_section(section).sum(&:yearly_cents)
      end
      surplus = sections["income"] - sections["bills"] - sections["everyday"]

      summary = sections.merge("surplus" => surplus).transform_values do |yearly_cents|
        {
          weekly: dollars(yearly_cents / 52.0),
          monthly: dollars(yearly_cents / 12.0),
          yearly: dollars(yearly_cents)
        }
      end
      { budget: summary }
    end

    def list_budget_items(args = {})
      section = args["section"].to_s
      unless BudgetItem::SECTIONS.key?(section)
        return { error: "section must be one of: #{BudgetItem::SECTIONS.keys.join(', ')}" }
      end

      items = @user.budget_items.in_section(section).where.not(amount_cents: 0).map do |item|
        { name: item.name, amount: dollars(item.amount_cents), frequency: item.frequency,
          yearly: dollars(item.yearly_cents) }
      end
      { section: section, items: items }
    end

    private

    def dollars(cents)
      (cents / 100.0).round(2)
    end
  end
end
