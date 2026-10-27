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

  test "get_will_plan summarises the plan, estate and open issues" do
    plan = @user.will
    plan.update!(executor_name: "Sam")
    alice = plan.beneficiaries.create!(name: "Alice", relationship: "sister", residue_share_pct: 100)
    plan.asset_instructions.create!(user_asset: user_assets(:one), ownership: "sole", will_beneficiary: alice)

    result = JSON.parse(@executor.execute("get_will_plan"))
    assert_equal "Sam", result["executor"]
    assert_equal 2500.0, result["estate"]["under_will"]
    assert_equal 1000.0, result["estate"]["debts_paid_by_estate"]
    assert_equal({ "name" => "Laptop", "value" => 2500.0, "held" => "In my name only", "goes_to" => "Alice" },
                 result["assets"].sole)
    assert_equal 1500.0, result["beneficiaries"].sole["estimated_total"]
    assert result["open_issues"].any? { |i| i.include?("backup executor") }
  end

  test "get_will_plan works before a plan exists and never shows another user's" do
    users(:two).will.tap(&:save!).beneficiaries.create!(name: "SECRET heir", residue_share_pct: 100)
    result = @executor.execute("get_will_plan")
    assert_no_match(/SECRET/, result)
    assert_match(/Name an executor/, result)
    assert_nil @user.reload.will_plan
  end

  def executor_with_library(vector)
    library = Ai::ReferenceLibrary.new(dir: Rails.root.join("test", "fixtures", "files", "reference_index"),
                                       embedder: ->(_) { [vector] })
    Ai::ToolExecutor.new(user: @user, reference_library: library)
  end

  test "search_reference_library returns excerpts with a citation note" do
    result = JSON.parse(executor_with_library([1, 0, 0, 0])
               .execute("search_reference_library", { "query" => "debt recycling", "top_k" => 2 }))

    assert_equal "Aussie FIRE episode 19: 19. Debt recycling", result["results"].first["source"]
    assert_match(/Name the source/, result["note"])
  end

  test "search_reference_library says when nothing is relevant" do
    result = JSON.parse(executor_with_library([0, 0, 0, 1])
               .execute("search_reference_library", { "query" => "pizza" }))

    assert_empty result["results"]
    assert_match(/general knowledge/, result["note"])
  end

  test "search_reference_library requires a query" do
    result = JSON.parse(executor_with_library([1, 0, 0, 0]).execute("search_reference_library", { "query" => " " }))
    assert_equal "query is required", result["error"]
  end

  test "search_reference_library reports a missing index as an error" do
    result = JSON.parse(@executor.execute("search_reference_library", { "query" => "super" }))
    assert_match(/not been built/, result["error"])
  end
end
