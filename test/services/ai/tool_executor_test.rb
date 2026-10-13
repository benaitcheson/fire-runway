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

  test "get_profile returns answered facts and lists the rest as unanswered" do
    @user.profile.update!(birth_year: Date.today.year - 36, gross_salary_cents: 12_000_000,
                          has_hecs: false, risk_tolerance: "growth", notes: "Expecting a bonus")

    result = JSON.parse(@executor.execute("get_profile"))
    assert_equal "36 (born #{Date.today.year - 36})", result["facts"]["About you"]["Age"]
    assert_equal "$120,000", result["facts"]["Income and work"]["Gross annual salary"]
    assert_equal "No", result["facts"]["Super and tax"]["HECS/HELP debt"]
    assert_equal FinancialProfile::RISK_TOLERANCES["growth"], result["facts"]["Attitudes"]["Risk tolerance"]
    assert_includes result["unanswered"], "Super balance"
    assert_not_includes result["unanswered"], "Gross annual salary"
    assert_equal 20, result["completeness_percent"]
  end

  test "get_profile with nothing answered is empty but well-formed" do
    result = JSON.parse(@executor.execute("get_profile"))
    assert_equal({}, result["facts"])
    assert_equal 0, result["completeness_percent"]
    assert_equal FinancialProfile::FIELDS.size, result["unanswered"].size
  end

  test "get_profile_gaps groups the unanswered questions by section" do
    @user.profile.update!(birth_year: 1990, relationship_status: "single", dependants_count: 0)

    result = JSON.parse(@executor.execute("get_profile_gaps"))
    sections = result["gaps"].map { |g| g["section"] }
    assert_not_includes sections, "About you"
    assert_includes sections, "Goals"
    goals = result["gaps"].find { |g| g["section"] == "Goals" }
    assert_includes goals["questions"], "At what age would you like to retire or be financially independent?"
  end

  test "profile tools never read another user's profile" do
    users(:two).profile.update!(notes: "SECRET other user")
    result = @executor.execute("get_profile")
    assert_no_match(/SECRET/, result)
  end

  test "list_budget_items validates section" do
    result = JSON.parse(@executor.execute("list_budget_items", { "section" => "shopping" }))
    assert_match(/section must be one of/, result["error"])
  end
end
