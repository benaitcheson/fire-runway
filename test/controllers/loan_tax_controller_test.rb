require "test_helper"

class LoanTaxControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "requires sign in" do
    delete logout_url
    get loan_tax_url
    assert_redirected_to login_url
  end

  test "renders with defaults" do
    get loan_tax_url
    assert_response :success
    assert_match 'value="120000"', response.body
    assert_match 'value="100000"', response.body
    assert_match "side by side", response.body
    assert_match "Year by year", response.body
  end

  test "remembers recalculated inputs and reopens with them" do
    get loan_tax_url, params: { gross_salary: 95_000, loan_amount: 80_000,
                                interest_rate: 9.5, loan_type: "interest_only",
                                term_years: 7, dividend_yield: 3.2,
                                franking_pct: 70, capital_growth: 6.1,
                                has_hecs: "1", hecs_balance: 20_000,
                                private_hospital_cover: "0" }
    assert_response :success
    @user.reload
    assert_equal 9_500_000, @user.loan_tax_gross_salary_cents
    assert_equal 8_000_000, @user.loan_tax_loan_amount_cents
    assert_equal 9.5, @user.loan_tax_interest_rate.to_f
    assert_equal "interest_only", @user.loan_tax_loan_type
    assert_equal 7, @user.loan_tax_term_years
    assert_equal 3.2, @user.loan_tax_dividend_yield.to_f
    assert_equal 2_000_000, @user.loan_tax_hecs_balance_cents
    assert_equal true, @user.loan_tax_has_hecs
    assert_equal false, @user.loan_tax_private_hospital_cover

    get loan_tax_url
    assert_response :success
    assert_match 'value="95000"', response.body
    assert_match 'value="9.5"', response.body
    assert_match "HECS repayment", response.body
  end

  test "params beat saved which beat defaults" do
    @user.update!(loan_tax_gross_salary_cents: 20_000_000)
    get loan_tax_url, params: { gross_salary: 60_000 }
    assert_response :success
    assert_match 'value="60000"', response.body
    assert_equal 6_000_000, @user.reload.loan_tax_gross_salary_cents
  end

  test "unchecked toggles persist false" do
    @user.update!(loan_tax_has_hecs: true, loan_tax_private_hospital_cover: true)
    get loan_tax_url, params: { gross_salary: 120_000, has_hecs: "0",
                                private_hospital_cover: "0" }
    assert_response :success
    @user.reload
    assert_equal false, @user.loan_tax_has_hecs
    assert_equal false, @user.loan_tax_private_hospital_cover
  end

  test "accepts non-round amounts" do
    get loan_tax_url, params: { gross_salary: 121_345.55, loan_amount: 98_765.43 }
    assert_response :success
    assert_equal 12_134_555, @user.reload.loan_tax_gross_salary_cents
    assert_equal 9_876_543, @user.loan_tax_loan_amount_cents
  end

  test "an invalid loan type falls back to principal and interest" do
    get loan_tax_url, params: { gross_salary: 120_000, loan_type: "yolo" }
    assert_response :success
    assert_equal "principal_and_interest", @user.reload.loan_tax_loan_type
  end

  test "shows the HECS gotcha callout when negatively geared with HECS" do
    get loan_tax_url, params: { gross_salary: 120_000, has_hecs: "1",
                                dividend_yield: 0, interest_rate: 10 }
    assert_response :success
    assert_match "HECS gotcha", response.body
  end

  test "a zero loan amount renders without results" do
    get loan_tax_url, params: { gross_salary: 120_000, loan_amount: 0 }
    assert_response :success
    assert_no_match "Year by year", response.body
  end
end
