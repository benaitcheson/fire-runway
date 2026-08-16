require "test_helper"

module UpBank
  class BudgetImporterTest < ActiveSupport::TestCase
    class FakeClient
      attr_reader :since_args

      def initialize(transactions)
        @transactions = transactions
        @since_args = []
      end

      def transactions(since:, before: nil)
        @since_args << since
        @transactions
      end
    end

    setup do
      @user = users(:one)
      @user.budget_items.destroy_all
    end

    test "averages category spending over the lookback window" do
      importer = importer_for([
        up_tx(cents: -15_000, category: "groceries"),
        up_tx(cents: -21_000, category: "groceries")
      ], lookback_months: 3)

      proposal = importer.call.sole
      assert_equal "everyday", proposal.section
      assert_equal "Groceries", proposal.name
      assert_equal 12_000, proposal.proposed_monthly_cents
      assert_equal 2, proposal.transaction_count
    end

    test "excludes internal transfers from expenses and income" do
      importer = importer_for([
        up_tx(cents: -50_000, category: "groceries", transfer: true),
        up_tx(cents: 500_000, transfer: true)
      ])

      assert_empty importer.call
    end

    test "merges restaurants and takeaway into one row" do
      importer = importer_for([
        up_tx(cents: -3_000, category: "restaurants-and-cafes"),
        up_tx(cents: -6_000, category: "takeaway")
      ], lookback_months: 3)

      proposal = importer.call.sole
      assert_equal "Restaurants & Take Aways", proposal.name
      assert_equal 3_000, proposal.proposed_monthly_cents
      assert_equal 2, proposal.transaction_count
    end

    test "nets refunds against their category and drops net-negative groups" do
      importer = importer_for([
        up_tx(cents: -4_000, category: "clothing-and-accessories"),
        up_tx(cents: 9_000, category: "clothing-and-accessories")
      ])

      assert_empty importer.call
    end

    test "proposes uncategorised credits as income" do
      importer = importer_for([
        up_tx(cents: 600_000, description: "TANDA PAYROLL"),
        up_tx(cents: 600_000, description: "TANDA PAYROLL")
      ], lookback_months: 3)

      proposal = importer.call.sole
      assert_equal "income", proposal.section
      assert_equal "Income 1 (Post Tax)", proposal.name
      assert_equal 400_000, proposal.proposed_monthly_cents
      assert_includes proposal.sample_descriptions, "TANDA PAYROLL"
    end

    test "unknown categories are flagged unmapped and not preselected" do
      importer = importer_for([up_tx(cents: -3_000, category: "crypto-losses")], lookback_months: 1)

      proposal = importer.call.sole
      assert proposal.unmapped
      assert_not proposal.preselected?
      assert_equal "Crypto Losses (Up)", proposal.name
      assert_equal "everyday", proposal.section
    end

    test "uncategorised debits are grouped but not preselected" do
      importer = importer_for([up_tx(cents: -3_000)], lookback_months: 1)

      proposal = importer.call.sole
      assert_equal "Uncategorised (Up)", proposal.name
      assert proposal.unmapped
    end

    test "fills current values and flags conflicts with entered amounts" do
      @user.budget_items.create!(section: "everyday", name: "Groceries",
                                 amount_cents: 30_000, frequency: "weekly")
      importer = importer_for([up_tx(cents: -90_000, category: "groceries")], lookback_months: 1)

      proposal = importer.call.sole
      assert_equal 30_000, proposal.current_amount_cents
      assert_equal "weekly", proposal.current_frequency
      assert_equal 130_000, proposal.current_monthly_cents
      assert proposal.conflict?
      assert_not proposal.preselected?
      assert_not proposal.new_row?
    end

    test "matching zero-amount template rows are preselected" do
      @user.budget_items.create!(section: "everyday", name: "Groceries",
                                 amount_cents: 0, frequency: "weekly")
      importer = importer_for([up_tx(cents: -90_000, category: "groceries")], lookback_months: 1)

      proposal = importer.call.sole
      assert_not proposal.conflict?
      assert proposal.preselected?
    end

    test "orders proposals income, bills, everyday" do
      importer = importer_for([
        up_tx(cents: -1_000, category: "groceries"),
        up_tx(cents: -2_000, category: "internet"),
        up_tx(cents: 5_000)
      ])

      assert_equal %w[income bills everyday], importer.call.map(&:section)
    end

    private

    def importer_for(transactions, lookback_months: 3)
      BudgetImporter.new(user: @user, client: FakeClient.new(transactions),
                         lookback_months: lookback_months)
    end

    def up_tx(cents:, category: nil, transfer: false, description: "Merchant")
      {
        "attributes" => {
          "description" => description,
          "amount" => { "valueInBaseUnits" => cents }
        },
        "relationships" => {
          "category" => { "data" => category && { "id" => category } },
          "transferAccount" => { "data" => transfer ? { "id" => "acct-2" } : nil }
        }
      }
    end
  end
end
