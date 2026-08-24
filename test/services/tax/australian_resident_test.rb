require "test_helper"

module Tax
  class AustralianResidentTest < ActiveSupport::TestCase
    # --- Progressive tax ---------------------------------------------------

    test "no tax below the tax-free threshold" do
      assert_equal 0.0, AustralianResident.tax_on(18_200)
    end

    test "tax at bracket boundaries" do
      assert_in_delta 4_288, AustralianResident.tax_on(45_000), 0.01
      assert_in_delta 26_788, AustralianResident.tax_on(120_000), 0.01
      assert_in_delta 31_288, AustralianResident.tax_on(135_000), 0.01
      assert_in_delta 51_638, AustralianResident.tax_on(190_000), 0.01
      assert_in_delta 56_138, AustralianResident.tax_on(200_000), 0.01
    end

    # --- LITO ---------------------------------------------------------------

    test "LITO is full below the first taper and gone above the cutout" do
      assert_equal 700.0, AustralianResident.lito(30_000)
      assert_in_delta 575.0, AustralianResident.lito(40_000), 0.01
      assert_in_delta 325.0, AustralianResident.lito(45_000), 0.01
      assert_equal 0.0, AustralianResident.lito(66_667)
      assert_equal 0.0, AustralianResident.lito(120_000)
    end

    # --- Medicare levy -------------------------------------------------------

    test "medicare levy phases in above the low-income threshold" do
      assert_equal 0.0, AustralianResident.medicare_levy(28_011)
      assert_in_delta 100.0, AustralianResident.medicare_levy(29_011), 0.01
      assert_in_delta 2_400.0, AustralianResident.medicare_levy(120_000), 0.01
    end

    # --- Medicare levy surcharge --------------------------------------------

    test "MLS tiers for singles" do
      assert_equal 0.0, AustralianResident.mls(101_000)
      assert_in_delta 1_100.0, AustralianResident.mls(110_000), 0.01
      assert_in_delta 1_500.0, AustralianResident.mls(120_000), 0.01
      assert_in_delta 1_625.0, AustralianResident.mls(130_000), 0.01
      assert_in_delta 2_400.0, AustralianResident.mls(160_000), 0.01
    end

    test "MLS is zero with private hospital cover" do
      assert_equal 0.0, AustralianResident.mls(160_000, private_hospital_cover: true)
    end

    test "net investment losses hold surcharge income up" do
      # $110k salary less $15k interest drops taxable income to $95k, but the
      # add-back keeps surcharge income at $110k — still tier 1.
      assessment = AustralianResident.assess(taxable_income: 95_000,
                                             net_investment_loss: 15_000)
      assert_equal 110_000, assessment.surcharge_income
      assert_in_delta 1_100.0, assessment.medicare_levy_surcharge, 0.01
    end

    # --- HECS/HELP -----------------------------------------------------------

    test "HECS marginal repayments" do
      assert_equal 0.0, AustralianResident.hecs_repayment(66_999)
      assert_in_delta 4_950.0, AustralianResident.hecs_repayment(100_000), 0.01
      assert_in_delta 12_950.0, AustralianResident.hecs_repayment(150_000), 0.01
      # Above $179,286 the repayment reverts to 10% of total income.
      assert_in_delta 20_000.0, AustralianResident.hecs_repayment(200_000), 0.01
    end

    test "HECS repayment is capped at the remaining balance" do
      assert_in_delta 1_000.0, AustralianResident.hecs_repayment(100_000, balance: 1_000), 0.01
    end

    test "negative gearing does not reduce HECS" do
      geared = AustralianResident.assess(taxable_income: 110_000,
                                         net_investment_loss: 10_000, has_hecs: true)
      ungeared = AustralianResident.assess(taxable_income: 120_000, has_hecs: true)
      assert_in_delta ungeared.hecs_repayment, geared.hecs_repayment, 0.01
    end

    # --- Franking and assess --------------------------------------------------

    test "franking credits are refundable" do
      assessment = AustralianResident.assess(taxable_income: 10_000,
                                             franking_credits: 3_000)
      assert assessment.total_payable.negative?, "expected a refund"
    end

    test "assess totals the components" do
      assessment = AustralianResident.assess(taxable_income: 120_000)
      assert_in_delta 26_788, assessment.base_tax, 0.01
      assert_in_delta 2_400, assessment.medicare_levy, 0.01
      assert_in_delta 1_500, assessment.medicare_levy_surcharge, 0.01
      assert_equal 0.0, assessment.hecs_repayment
      assert_in_delta 30_688, assessment.total_payable, 0.01
    end

    # --- Marginal rate ----------------------------------------------------------

    test "marginal rate matches the old controller contract" do
      assert_nil AustralianResident.marginal_rate(18_000)
      assert_equal 18.0, AustralianResident.marginal_rate(30_000)
      assert_equal 32.0, AustralianResident.marginal_rate(120_000)
      assert_equal 39.0, AustralianResident.marginal_rate(150_000)
      assert_equal 47.0, AustralianResident.marginal_rate(250_000)
    end
  end
end
