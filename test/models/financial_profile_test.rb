require "test_helper"

class FinancialProfileTest < ActiveSupport::TestCase
  setup { @profile = users(:one).profile }

  test "every field maps to a real column" do
    FinancialProfile::FIELDS.each do |field|
      assert FinancialProfile.column_names.include?(field.column.to_s), "missing column for #{field.name}"
    end
  end

  test "field names are unique and every field has a question" do
    names = FinancialProfile::FIELDS.map(&:name)
    assert_equal names.uniq, names
    assert FinancialProfile::FIELDS.all? { |f| f.question.present? && f.label.present? }
  end

  test "starts empty with zero completeness" do
    assert_equal 0, @profile.completeness_pct
    assert_empty @profile.answered_fields
    assert_equal FinancialProfile::FIELDS.size, @profile.missing_fields.size
  end

  test "money accessors convert dollars to cents and back" do
    @profile.gross_salary = "123456.78"
    assert_equal 12_345_678, @profile.gross_salary_cents
    assert_equal 123_456.78, @profile.gross_salary

    @profile.gross_salary = ""
    assert_nil @profile.gross_salary_cents
  end

  test "blank form values stay unanswered rather than becoming empty answers" do
    @profile.update!(goals: "   ", relationship_status: "", has_will: "", dependants_count: "")
    assert_nil @profile.goals
    assert_nil @profile.relationship_status
    assert_nil @profile.has_will
    assert_nil @profile.dependants_count
    assert_equal 0, @profile.completeness_pct
  end

  test "a false boolean counts as answered" do
    @profile.update!(has_hecs: false)
    assert_equal 1, @profile.answered_fields.size
    assert_equal "No", @profile.display_value(FinancialProfile::FIELDS_BY_NAME[:has_hecs])
  end

  test "completeness and facts reflect what has been answered" do
    @profile.update!(birth_year: Date.today.year - 40, super_balance: 85_000.5,
                     super_employer_rate: 12, employment_type: "self_employed")

    assert_equal (4 * 100.0 / FinancialProfile::FIELDS.size).round, @profile.completeness_pct
    assert_equal 40, @profile.age
    facts = @profile.facts
    assert_equal "40 (born #{Date.today.year - 40})", facts["About you"]["Age"]
    assert_equal "$85,001", facts["Super and tax"]["Super balance"]
    assert_equal "12%", facts["Super and tax"]["Employer super rate"]
    assert_equal "Self-employed / business owner", facts["Income and work"]["Employment"]
    assert_nil facts["Goals"]
  end

  test "rejects nonsense values" do
    @profile.assign_attributes(birth_year: 1850, target_retirement_age: 5, risk_tolerance: "yolo",
                               super_employer_rate: 150, gross_salary: -5)
    assert_not @profile.valid?
    %i[birth_year target_retirement_age risk_tolerance super_employer_rate gross_salary_cents].each do |attr|
      assert @profile.errors[attr].any?, "expected an error on #{attr}"
    end
  end

  test "user.profile builds one profile and reuses it" do
    user = users(:two)
    assert_nil user.financial_profile
    profile = user.profile
    assert profile.new_record?
    assert_same profile, user.profile

    profile.update!(birth_year: 1995)
    assert_equal 1995, user.reload.financial_profile.birth_year
  end

  test "profile is destroyed with the user" do
    user = users(:two)
    user.profile.update!(birth_year: 1995)
    assert_difference("FinancialProfile.count", -1) { user.destroy! }
  end
end
