# Tool definitions for the Ollama chat API (OpenAI function-call format).
# Every tool is read-only. The model never sees the database — each tool
# dispatches to a method on Ai::ToolExecutor scoped to the current user.
module Ai
  module Tools
    ALL = [
      {
        type: "function",
        function: {
          name: "get_profile",
          description: "The user's fact-finder profile: age, household, employment, salary, " \
                       "super, HECS, housing, retirement goals, risk tolerance, insurance and " \
                       "notes. Unanswered fields are listed separately.",
          parameters: { type: "object", properties: {}, required: [] }
        }
      },
      {
        type: "function",
        function: {
          name: "get_profile_gaps",
          description: "Profile questions the user has not answered yet, each with the " \
                       "question to ask them. Use this to find what to ask when advice " \
                       "depends on a missing fact.",
          parameters: { type: "object", properties: {}, required: [] }
        }
      },
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
      },
      {
        type: "function",
        function: {
          name: "search_reference_library",
          description: "Search the user's reference library of Australian personal finance " \
                       "podcast transcripts and books for what experts say about a topic: " \
                       "strategies, rules of thumb, explanations and examples (debt recycling, " \
                       "FIRE, super contributions, ETFs, offset vs invest, and so on). Returns " \
                       "excerpts with their source and date. Not for the user's own numbers.",
          parameters: {
            type: "object",
            properties: {
              query: { type: "string",
                       description: "What to look up, phrased as a question or topic" },
              top_k: { type: "integer", description: "Number of excerpts, 1-5 (default 3)" }
            },
            required: ["query"]
          }
        }
      }
    ].freeze

    def self.names
      ALL.map { |t| t[:function][:name] }
    end

    # The tools offered to the model: the reference search is left out when
    # no index has been built, so the model never calls a dead tool.
    def self.for(reference_library:)
      return ALL if reference_library.available?

      ALL.reject { |t| t[:function][:name] == "search_reference_library" }
    end
  end
end
