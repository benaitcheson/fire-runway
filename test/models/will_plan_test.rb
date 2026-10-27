require "test_helper"

class WillPlanTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @plan = @user.will
    @plan.save!
    @laptop = user_assets(:one)
  end

  test "an asset passing outside the will can't be gifted" do
    alice = @plan.beneficiaries.create!(name: "Alice", residue_share_pct: 100)
    instruction = @plan.asset_instructions.build(user_asset: @laptop, ownership: "joint_tenants", will_beneficiary: alice)

    assert_not instruction.valid?
    assert_match(/passes outside your will .* can't be gifted/, instruction.errors[:base].first)
  end

  test "tenants in common needs the user's share" do
    instruction = @plan.asset_instructions.build(user_asset: @laptop, ownership: "tenants_in_common")
    assert_not instruction.valid?
    assert instruction.errors.of_kind?(:owned_share_pct, :not_a_number)
  end

  test "instructions can't point at another user's asset or another plan's beneficiary" do
    other_plan = users(:two).will.tap(&:save!)
    stranger = other_plan.beneficiaries.create!(name: "Stranger", residue_share_pct: 100)

    foreign_asset = @plan.asset_instructions.build(user_asset: user_assets(:two), ownership: "sole")
    assert_not foreign_asset.valid?
    assert_includes foreign_asset.errors[:user_asset], "is not yours"

    foreign_gift = @plan.asset_instructions.build(user_asset: @laptop, ownership: "sole", will_beneficiary: stranger)
    assert_not foreign_gift.valid?
    assert_includes foreign_gift.errors[:will_beneficiary], "is not in this plan"
  end

  test "a debt can only be secured on the user's own asset" do
    instruction = @plan.liability_instructions.build(user_liability: user_liabilities(:one), secured_asset: user_assets(:two))
    assert_not instruction.valid?
    assert_includes instruction.errors[:secured_asset], "is not yours"

    foreign = @plan.liability_instructions.build(user_liability: user_liabilities(:two))
    assert_not foreign.valid?
    assert_includes foreign.errors[:user_liability], "is not yours"
  end

  test "deleting a secured asset leaves its debt unsecured; deleting a debt removes its instruction" do
    instruction = @plan.liability_instructions.create!(user_liability: user_liabilities(:one), secured_asset: @laptop)
    @laptop.destroy!
    assert_nil instruction.reload.secured_asset_id

    assert_difference("WillLiabilityInstruction.count", -1) { user_liabilities(:one).destroy! }
  end

  test "a beneficiary whose share goes to someone else must name them" do
    beneficiary = @plan.beneficiaries.build(name: "Alice", fallback: "named")
    assert_not beneficiary.valid?
    beneficiary.fallback_name = "Alice's partner"
    assert beneficiary.valid?
    assert_equal "Alice's partner", beneficiary.fallback_description
  end

  test "blank add-someone rows are ignored and names are trimmed" do
    @plan.update!(executor_name: "  Sam  ", beneficiaries_attributes: [
      { name: "Alice", residue_share_pct: "100" }, { name: "", relationship: "", residue_share_pct: "" }
    ])
    assert_equal ["Alice"], @plan.beneficiaries.map(&:name)
    assert_equal "Sam", @plan.executor_name
  end

  test "marking the will signed answers the profile question" do
    assert_nil @user.profile.has_will
    @plan.update!(will_status: "signed", signed_on: Date.current)
    assert_equal true, @user.reload.profile.has_will
  end

  test "signed date can't be in the future" do
    @plan.signed_on = Date.tomorrow
    assert_not @plan.valid?
  end

  test "deleting an asset or a beneficiary cleans up the plan" do
    alice = @plan.beneficiaries.create!(name: "Alice", residue_share_pct: 100)
    bike = @user.user_assets.create!(item_name: "Bike", purchase_price_cents: 100_000,
                                     purchase_price_currency: "AUD", purchase_date: Date.new(2024, 1, 1))
    gift = @plan.asset_instructions.create!(user_asset: @laptop, ownership: "sole", will_beneficiary: alice)
    @plan.asset_instructions.create!(user_asset: bike, ownership: "sole")

    alice.destroy!
    assert_nil gift.reload.will_beneficiary_id, "the gift falls back into the residue"

    assert_difference("WillAssetInstruction.count", -1) { bike.destroy! }
  end

  test "instructions_for_assets covers every asset, defaulting to sole ownership" do
    instructions = @plan.instructions_for_assets
    assert_equal [@laptop], instructions.map(&:user_asset)
    assert_equal "sole", instructions.first.ownership
    assert instructions.first.new_record?
  end
end
