# Tool definitions for the Ollama chat API (OpenAI function-call format).
# Every tool is read-only. The model never sees the database — each tool
# dispatches to a method on Ai::ToolExecutor scoped to the current user.
module Ai
  module Tools
    ALL = [
      {
        type: "function",
        function: {
          name: "get_net_worth_summary",
          description: "Totals for the user's finances: asset purchase and current values, " \
                       "total liabilities, net worth, and counts. Call this for any question " \
                       "about overall position or net worth.",
          parameters: { type: "object", properties: {}, required: [] }
        }
      },
      {
        type: "function",
        function: {
          name: "list_assets",
          description: "List the user's assets with purchase price, current (depreciated) value, " \
                       "purchase date and depreciation method.",
          parameters: { type: "object", properties: {}, required: [] }
        }
      },
      {
        type: "function",
        function: {
          name: "list_liabilities",
          description: "List the user's liabilities (debts) with amounts.",
          parameters: { type: "object", properties: {}, required: [] }
        }
      },
      {
        type: "function",
        function: {
          name: "get_asset_depreciation",
          description: "Depreciation detail for one asset matched by name: current value, " \
                       "annual depreciation, and projected value by year.",
          parameters: {
            type: "object",
            properties: {
              name: { type: "string", description: "Asset name (case-insensitive, partial match allowed)" }
            },
            required: ["name"]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "get_budget_summary",
          description: "The user's budget totals: income, bills, everyday spending and surplus, " \
                       "normalised to weekly, monthly and yearly amounts.",
          parameters: { type: "object", properties: {}, required: [] }
        }
      },
      {
        type: "function",
        function: {
          name: "list_budget_items",
          description: "List budget line items in one section with amount and frequency. " \
                       "Only items with a non-zero amount are returned.",
          parameters: {
            type: "object",
            properties: {
              section: { type: "string", enum: BudgetItem::SECTIONS.keys,
                         description: "income, bills or everyday" }
            },
            required: ["section"]
          }
        }
      }
    ].freeze

    def self.names
      ALL.map { |t| t[:function][:name] }
    end
  end
end
