require "test_helper"

class FinancialProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "requires sign in" do
    delete logout_url
    get profile_url
    assert_redirected_to login_url
  end

  test "renders every section and question" do
    get profile_url
    assert_response :success
    FinancialProfile::SECTIONS.each_value do |section|
      assert_match section[:title], response.body
      section[:fields].each { |f| assert_select "[name='financial_profile[#{f.name}]']", 1 }
    end
    assert_match "0% complete", response.body.gsub(/\s+/, " ").sub("0% (0", "0% complete (0")
  end

  test "saves answers across every field type and reopens with them" do
    patch profile_url, params: { financial_profile: {
      birth_year: 1988, relationship_status: "couple_combined", dependants_count: 2,
      employment_type: "full_time", gross_salary: "145000", income_stability: "stable",
      partner_gross_salary: "90000", super_balance: "210500.25", super_employer_rate: "12",
      super_salary_sacrifice_monthly: "500", has_hecs: "true",
      hecs_balance: "18000", private_hospital_cover: "false", housing_status: "mortgage",
      target_retirement_age: 55, retirement_spend_monthly: "6000", emergency_fund_months: 6,
      goals: "Pay off the mortgage by 50", risk_tolerance: "growth",
      investment_experience: "some", concerns: "Market crash near retirement",
      has_income_protection: "true", has_life_insurance: "true", has_will: "false",
      notes: "Bonus of ~$20k most years"
    } }
    assert_redirected_to profile_url
    follow_redirect!
    assert_match "Profile saved", response.body

    profile = @user.reload.profile
    assert_equal 1988, profile.birth_year
    assert_equal 14_500_000, profile.gross_salary_cents
    assert_equal 21_050_025, profile.super_balance_cents
    assert_equal true, profile.has_hecs
    assert_equal false, profile.private_hospital_cover
    assert_equal false, profile.has_will
    assert_equal "Bonus of ~$20k most years", profile.notes
    assert_equal 100, profile.completeness_pct
    assert_match "100% (#{FinancialProfile::FIELDS.size} of #{FinancialProfile::FIELDS.size})", response.body
    assert_select "select[name='financial_profile[has_will]'] option[selected][value=false]"
    assert_select "input[name='financial_profile[super_balance]'][value='210500.25']"
  end

  test "blank answers clear a previously saved value" do
    @user.profile.update!(birth_year: 1988, has_hecs: true)
    patch profile_url, params: { financial_profile: { birth_year: "", has_hecs: "" } }
    assert_redirected_to profile_url
    profile = @user.reload.profile
    assert_nil profile.birth_year
    assert_nil profile.has_hecs
  end

  test "invalid values re-render the form with errors" do
    patch profile_url, params: { financial_profile: { birth_year: 1800, risk_tolerance: "yolo" } }
    assert_response :unprocessable_entity
    assert_match "prohibited this profile", response.body
    assert_select "[role=alert]", text: /Profile not saved/
    assert_nil @user.reload.financial_profile
  end

  test "cannot write to another user's profile through mass assignment" do
    patch profile_url, params: { financial_profile: { user_id: users(:two).id, birth_year: 1990 } }
    assert_redirected_to profile_url
    assert_equal @user.id, @user.reload.financial_profile.user_id
    assert_nil users(:two).financial_profile
  end

  test "form submits as a full page load so the flash shows at the top" do
    get profile_url
    assert_select "form[action='#{profile_path}'][data-turbo=false]"
  end

  test "nav marks the profile section" do
    get profile_url
    assert_select "nav a[aria-current=page]", text: "Profile"
  end

  test "ai assistant page nudges an incomplete profile" do
    with_fake_ollama { get ai_assistant_url }
    assert_response :success
    assert_match "0% complete", response.body
    assert_select "a[href='#{profile_path}']"
  end

  private

  # The assistant page lists Ollama models on load; swap the client for a stub
  # so the test never touches the network. Tests run in separate processes, so
  # the class-level override is safe.
  def with_fake_ollama
    fake = Object.new.tap { |o| o.define_singleton_method(:list_models) { {} } }
    OllamaService.singleton_class.alias_method(:original_new, :new)
    OllamaService.define_singleton_method(:new) { |*| fake }
    yield
  ensure
    OllamaService.singleton_class.alias_method(:new, :original_new)
    OllamaService.singleton_class.remove_method(:original_new)
  end
end
