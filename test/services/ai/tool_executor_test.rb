require "test_helper"

class Ai::ToolExecutorTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @executor = Ai::ToolExecutor.new(user: @user)
  end

  test "rejects unknown tools" do
    result = JSON.parse(@executor.execute("drop_table"))
    assert_match(/Unknown tool/, result["error"])
  end

  test "net worth summary uses only this user's records" do
    result = JSON.parse(@executor.execute("get_net_worth_summary"))
    assert_equal 1, result["asset_count"]
    assert_equal 2500.0, result["total_assets_current_value"]
    assert_equal 1000.0, result["total_liabilities"]
    assert_equal 1500.0, result["net_worth"]
  end

  test "list_assets does not include other users' assets" do
    result = JSON.parse(@executor.execute("list_assets"))
    names = result["assets"].map { |a| a["name"] }
    assert_includes names, "Laptop"
    assert_not_includes names, "Camera"
  end

  test "get_asset_depreciation matches by partial name" do
    result = JSON.parse(@executor.execute("get_asset_depreciation", { "name" => "lap" }))
    assert_equal "Laptop", result["name"]
    assert result["projected_values"].any?
  end

  test "get_asset_depreciation contains errors instead of raising" do
    result = JSON.parse(@executor.execute("get_asset_depreciation", { "name" => "yacht" }))
    assert_match(/No asset matching/, result["error"])
  end

  test "budget summary computes surplus across sections" do
    @user.budget_items.create!(section: "income", name: "Salary", amount_cents: 520_000, frequency: "weekly")
    @user.budget_items.create!(section: "bills", name: "Rent", amount_cents: 120_000, frequency: "weekly")

    result = JSON.parse(@executor.execute("get_budget_summary"))
    assert_equal 400_000 * 52 / 100.0, result["budget"]["surplus"]["yearly"]
    assert_equal 4000.0, result["budget"]["surplus"]["weekly"]
  end

  test "list_budget_items validates section" do
    result = JSON.parse(@executor.execute("list_budget_items", { "section" => "shopping" }))
    assert_match(/section must be one of/, result["error"])
  end
end
