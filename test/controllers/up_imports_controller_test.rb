require "test_helper"

class UpImportsControllerTest < ActionDispatch::IntegrationTest
  FakeImporter = Struct.new(:proposals) do
    def call = proposals
  end

  setup do
    @user = users(:one)
    sign_in_as @user
    @previous_token = ENV["UP_API_TOKEN"]
    @previous_factory = UpImportsController.importer_factory
    ENV["UP_API_TOKEN"] = "up:yeah:test"
  end

  teardown do
    ENV["UP_API_TOKEN"] = @previous_token
    UpImportsController.importer_factory = @previous_factory
  end

  test "requires sign in" do
    delete logout_url
    get new_up_import_url
    assert_redirected_to login_url
  end

  test "preview redirects with a hint when the token is not set" do
    ENV["UP_API_TOKEN"] = nil
    get new_up_import_url
    assert_redirected_to budget_url
    assert_match(/UP_API_TOKEN/, flash[:alert])
  end

  test "preview renders proposals from the importer" do
    proposal = UpBank::Proposal.new(section: "everyday", name: "Groceries",
                                    proposed_monthly_cents: 64_512, transaction_count: 12,
                                    sample_descriptions: ["Coles", "Woolworths"], unmapped: false)
    UpImportsController.importer_factory = ->(user:, lookback_months:) { FakeImporter.new([proposal]) }

    get new_up_import_url
    assert_response :success
    assert_match "Groceries", response.body
    assert_match "645.12", response.body
    assert_match "Coles", response.body
    assert_match 'name="proposals[0][proposed_monthly_cents]" value="64512"', response.body
  end

  test "preview shows a distinct message for a rejected token" do
    UpImportsController.importer_factory = ->(**) { raise UpBank::AuthError, "401" }
    get new_up_import_url
    assert_redirected_to budget_url
    assert_match(/rejected the API token/, flash[:alert])
  end

  test "preview reports network failures" do
    UpImportsController.importer_factory = ->(**) { raise UpBank::ApiError, "timeout" }
    get new_up_import_url
    assert_redirected_to budget_url
    assert_match(/Couldn't reach Up/, flash[:alert])
  end

  test "apply updates checked rows and creates missing ones" do
    existing = @user.budget_items.create!(section: "everyday", name: "Groceries",
                                          amount_cents: 10_000, frequency: "weekly")

    post up_import_url, params: { proposals: {
      "0" => { include: "1", section: "everyday", name: "Groceries", proposed_monthly_cents: "64512" },
      "1" => { include: "1", section: "bills", name: "Internet", proposed_monthly_cents: "8000" }
    } }

    assert_redirected_to budget_url
    assert_equal 64_512, existing.reload.amount_cents
    assert_equal "monthly", existing.frequency
    created = @user.budget_items.find_by!(section: "bills", name: "Internet")
    assert_equal 8_000, created.amount_cents
    assert created.position.positive?
  end

  test "apply skips unchecked rows and invalid sections" do
    post up_import_url, params: { proposals: {
      "0" => { section: "everyday", name: "Skipped", proposed_monthly_cents: "5000" },
      "1" => { include: "1", section: "hacks", name: "Bad", proposed_monthly_cents: "5000" }
    } }

    assert_redirected_to budget_url
    assert_nil @user.budget_items.find_by(name: "Skipped")
    assert_nil @user.budget_items.find_by(name: "Bad")
    assert_match(/Updated 0/, flash[:notice])
  end

  test "apply is idempotent on replay" do
    params = { proposals: { "0" => { include: "1", section: "bills", name: "Internet",
                                     proposed_monthly_cents: "8000" } } }
    post up_import_url, params: params
    post up_import_url, params: params

    assert_equal 1, @user.budget_items.where(name: "Internet").count
  end
end
