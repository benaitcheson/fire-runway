require "test_helper"

class WillPlansControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @laptop = user_assets(:one)
    sign_in_as @user
  end

  def text = response.body.gsub(/\s+/, " ")

  test "a new user sees the planner with their assets, debts and the essentials missing" do
    get will_url
    assert_response :success
    assert_select "h1", "Will planner"
    assert_select "select[name='will_plan[asset_instructions_attributes][0][ownership]']"
    assert_select "input[name='will_plan[asset_instructions_attributes][0][user_asset_id]'][value='#{@laptop.id}']"
    assert_select "input[name^='will_plan[beneficiaries_attributes]'][name$='[name]']", 2
    assert_match "Laptop", text
    assert_match "Name an executor", text
    assert_nil @user.reload.will_plan, "viewing the page doesn't create a plan"
  end

  test "saves people, beneficiaries and asset instructions in one go" do
    patch will_url, params: { will_plan: {
      state: "VIC", executor_name: "Sam Lee", executor_relationship: "partner", backup_executor_name: "Jo",
      super_nomination: "binding_non_lapsing", super_nominee: "Sam", will_status: "planning",
      funeral_wishes: "Cremation",
      beneficiaries_attributes: { "0" => { name: "Sam Lee", relationship: "partner", residue_share_pct: "100",
                                           fallback: "their_children" },
                                  "1" => { name: "", relationship: "", residue_share_pct: "" } },
      asset_instructions_attributes: { "0" => { user_asset_id: @laptop.id, ownership: "sole" } }
    } }
    assert_redirected_to will_url

    plan = @user.reload.will_plan
    assert_equal "Sam Lee", plan.executor_name
    assert_equal ["Sam Lee"], plan.beneficiaries.map(&:name)
    assert_equal "sole", plan.asset_instructions.sole.ownership

    # Gift the laptop now that Sam exists as a beneficiary.
    sam = plan.beneficiaries.first
    instruction = plan.asset_instructions.first
    patch will_url, params: { will_plan: { asset_instructions_attributes: {
      "0" => { id: instruction.id, user_asset_id: @laptop.id, ownership: "sole", will_beneficiary_id: sam.id }
    } } }
    assert_equal sam, instruction.reload.will_beneficiary

    get will_url
    assert_match "Who gets what", text
    assert_match "State Trustees", text
  end

  test "a debt can be marked as secured on an asset" do
    patch will_url, params: { will_plan: {
      asset_instructions_attributes: { "0" => { user_asset_id: @laptop.id, ownership: "joint_tenants" } },
      liability_instructions_attributes: { "0" => { user_liability_id: user_liabilities(:one).id, secured_asset_id: @laptop.id } }
    } }
    assert_redirected_to will_url
    assert_equal @laptop, @user.will_plan.liability_instructions.sole.secured_asset

    get will_url
    assert_match "Goes with Laptop, outside the will", text
    get summary_will_url
    assert_match "secured on Laptop; goes with it outside the will", text
  end

  test "invalid input re-renders with named errors and saves nothing" do
    patch will_url, params: { will_plan: {
      executor_name: "Sam",
      beneficiaries_attributes: { "0" => { name: "Alice", residue_share_pct: "150" } },
      asset_instructions_attributes: { "0" => { user_asset_id: @laptop.id, ownership: "tenants_in_common" } }
    } }
    assert_response :unprocessable_entity
    assert_match "Alice: Residue share pct must be in 0..100", text
    assert_match "Laptop: Owned share pct", text
    assert_nil @user.reload.will_plan
  end

  test "removing a beneficiary sends their gifts back to the residue" do
    plan = @user.will.tap(&:save!)
    alice = plan.beneficiaries.create!(name: "Alice", residue_share_pct: 100)
    gift = plan.asset_instructions.create!(user_asset: @laptop, ownership: "sole", will_beneficiary: alice)

    patch will_url, params: { will_plan: { beneficiaries_attributes: { "0" => { id: alice.id, _destroy: "1" } } } }
    assert_redirected_to will_url
    assert_empty plan.beneficiaries.reload
    assert_nil gift.reload.will_beneficiary_id
  end

  test "the printable summary lists the plan and what is still missing" do
    plan = @user.will
    plan.update!(executor_name: "Sam Lee", state: "NSW", other_wishes: "Look after the dog")
    alice = plan.beneficiaries.create!(name: "Alice", relationship: "sister", residue_share_pct: 100)
    plan.asset_instructions.create!(user_asset: @laptop, ownership: "sole", will_beneficiary: alice)

    get summary_will_url
    assert_response :success
    assert_match "Instructions for my will", text
    assert_match "Sam Lee", text
    assert_match "Laptop", text
    assert_match "to Alice (sister)", text
    assert_match "Look after the dog", text
    assert_match "NSW Trustee &amp; Guardian", text
    assert_select "[data-action='print#print']"
  end

  test "summary works before anything is saved" do
    get summary_will_url
    assert_response :success
    assert_match "Still to sort out", text
  end
end
