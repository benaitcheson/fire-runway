require "test_helper"

class WillPlanner::EstateTest < ActiveSupport::TestCase
  # users(:one) starts with a $2,500 laptop and a $1,000 debt.
  setup do
    @user = users(:one)
    @plan = @user.will
    @plan.save!
  end

  def add_asset(name, dollars)
    @user.user_assets.create!(item_name: name, purchase_price_cents: dollars * 100,
                              purchase_price_currency: "AUD", purchase_date: Date.new(2024, 1, 1))
  end

  def hold(asset, ownership, share: nil, to: nil)
    @plan.asset_instructions.create!(user_asset: asset, ownership: ownership, owned_share_pct: share,
                                     will_beneficiary: to)
  end

  def add_beneficiary(name, share, relationship: nil)
    @plan.beneficiaries.create!(name: name, residue_share_pct: share, relationship: relationship)
  end

  def estate = WillPlanner::Estate.new(@plan.reload)
  def messages(level = nil) = estate.checks.select { |c| level.nil? || c.level == level }.map(&:message)

  test "an empty plan puts everything in the residue and asks for the essentials" do
    assert_equal 250_000, estate.gross_cents
    assert_equal 100_000, estate.debts_cents
    assert_equal 150_000, estate.net_cents
    assert_equal 150_000, estate.residue_cents
    assert_equal ["Residue"], estate.rows.map(&:recipient)

    actions = messages(:action)
    assert actions.any? { |m| m.start_with?("Name an executor") }
    assert actions.any? { |m| m.start_with?("Add at least one beneficiary") }
    assert_not estate.ready?
  end

  test "only sole assets and a tenants in common share are in the estate" do
    hold(add_asset("Unit", 600_000), "tenants_in_common", share: 50)
    hold(add_asset("Car", 20_000), "joint_tenants")
    hold(add_asset("Family trust shares", 50_000), "outside_will")

    assert_equal 250_000 + 300_000_00, estate.gross_cents
    assert_equal 70_000_00, estate.outside_cents
    car = estate.rows.find { |r| r.asset_name == "Car" }
    assert_equal :outside, car.route
    assert_equal "Surviving co-owner", car.recipient
    assert messages(:tip).any? { |m| m.start_with?("Car passes to the surviving co-owner") }
  end

  test "gifts come off the top and the residue is split by share after debts" do
    alice = add_beneficiary("Alice", 60, relationship: "sister")
    add_beneficiary("Bob", 40)
    hold(add_asset("Bike", 3_000), "sole", to: alice)
    @plan.update!(executor_name: "Alice", backup_executor_name: "Bob")

    # Estate $5,500, debts $1,000, gift $3,000: residue $1,500.
    assert_equal 150_000, estate.residue_cents
    alice_gets, bob_gets = estate.inheritances
    assert_equal ["Bike"], alice_gets.gift_names
    assert_equal 300_000, alice_gets.gift_cents
    assert_equal 90_000, alice_gets.residue_cents
    assert_equal 390_000, alice_gets.total_cents
    assert_equal 60_000, bob_gets.total_cents
    assert estate.ready?, messages.inspect
  end

  test "gifts shrink in proportion when debts are bigger than the residue" do
    alice = add_beneficiary("Alice", 100)
    hold(users(:one).user_assets.first, "sole", to: alice) # the $2,500 laptop, all gifted
    @user.user_liabilities.create!(item_name: "Card", amount_cents: 50_000, amount_currency: "AUD")

    # Debts $1,500 against a $2,500 estate that is entirely gifted.
    assert_equal 0, estate.residue_cents
    assert_equal 150_000, estate.gift_shortfall_cents
    assert_equal 100_000, estate.inheritances.first.gift_cents
    assert messages(:warning).any? { |m| m.include?("gifted assets would have to be sold") }
  end

  def secure(liability, asset)
    @plan.liability_instructions.create!(user_liability: liability, secured_asset: asset)
  end

  def add_debt(name, dollars)
    @user.user_liabilities.create!(item_name: name, amount_cents: dollars * 100, amount_currency: "AUD")
  end

  test "a loan on a joint tenancy home goes with the home, not the estate" do
    home = add_asset("Home", 900_000)
    hold(home, "joint_tenants")
    secure(add_debt("Home loan", 600_000), home)

    assert_equal 100_000, estate.debts_cents, "only the $1,000 unsecured debt is the estate's"
    assert_equal 150_000, estate.net_cents
    assert_equal 600_000_00, estate.outside_debts_cents
    loan = estate.debt_rows.find { |d| d.name == "Home loan" }
    assert_equal :with_asset, loan.treatment
    assert messages(:tip).any? { |m| m.start_with?("Home loan ($600,000) goes with Home outside your will") }
    assert messages.none? { |m| m.include?("pick that asset under Your debts") }
  end

  test "a gifted asset passes with its loan, and a loan bigger than the gift falls on the estate" do
    alice = add_beneficiary("Alice", 100)
    car = add_asset("Car", 20_000)
    hold(car, "sole", to: alice)
    secure(add_debt("Car loan", 15_000), car)

    alice_gets = estate.inheritances.sole
    assert_equal 5_000_00, alice_gets.gift_cents, "the $20,000 car less its $15,000 loan"
    assert_equal 15_000_00, estate.gift_carried_cents
    assert_equal 100_000, estate.debts_cents
    assert_equal 150_000, estate.residue_cents
    assert messages(:tip).any? { |m| m.start_with?("Car passes to Alice with Car loan ($15,000) secured on it") }

    add_debt("Top-up", 10_000).then { |top_up| secure(top_up, car) }
    # $25,000 secured on a $20,000 car: the gift is worth nothing and $5,000 falls on the estate.
    assert_equal 0, estate.inheritances.sole.gift_cents
    assert_equal 100_000 + 5_000_00, estate.debts_cents
  end

  test "a loan on a residue asset is an ordinary estate debt" do
    unit = add_asset("Unit", 500_000)
    secure(add_debt("Unit loan", 400_000), unit)
    assert_equal 100_000 + 400_000_00, estate.debts_cents
    assert_equal :estate, estate.debt_rows.find { |d| d.name == "Unit loan" }.treatment
  end

  test "unlinked debts prompt the user to say what they're secured on" do
    assert messages(:tip).any? { |m| m.include?("pick that asset under Your debts") }
  end

  test "debts bigger than the whole estate are called out" do
    @user.user_liabilities.create!(item_name: "Loan", amount_cents: 1_000_000, amount_currency: "AUD")
    assert estate.net_cents.negative?
    assert_equal 0, estate.residue_cents
    assert messages(:warning).any? { |m| m.include?("don't personally inherit debts") }
  end

  test "residue shares must total 100%" do
    add_beneficiary("Alice", 50)
    add_beneficiary("Bob", 30)
    assert messages(:action).any? { |m| m.start_with?("Residue shares add up to 80%") }
  end

  test "super without a binding nomination is flagged, and profile super isn't double counted" do
    @user.profile.update!(super_balance_cents: 100_000_00)
    assert_equal 100_000_00, estate.profile_super_cents
    assert messages(:warning).any? { |m| m.include?("$100,000 of super doesn't follow your will") }

    @plan.update!(super_nomination: "binding_non_lapsing")
    assert messages.none? { |m| m.include?("doesn't follow your will") }

    hold(add_asset("AustralianSuper super", 120_000), "sole")
    assert_equal 0, estate.profile_super_cents, "super listed as an asset replaces the profile balance"
    assert messages(:warning).any? { |m| m.start_with?("AustralianSuper super looks like super") }
  end

  test "dependants without a guardian need one" do
    @user.profile.update!(dependants_count: 2)
    assert messages(:action).any? { |m| m.include?("name a guardian") }

    @plan.update!(guardian_name: "Carol")
    assert messages(:action).none? { |m| m.include?("name a guardian") }
    assert messages(:tip).any? { |m| m.include?("backup guardian") }
  end

  test "a partnered user who leaves their partner nothing is warned" do
    @user.profile.update!(relationship_status: "couple_combined")
    add_beneficiary("Dan", 100, relationship: "brother")
    assert messages(:warning).any? { |m| m.include?("family provision claim") }

    @plan.beneficiaries.first.update!(relationship: "de facto partner")
    assert messages(:warning).none? { |m| m.include?("family provision claim") }
  end

  test "an old signed will is due for review" do
    @plan.update!(will_status: "signed", signed_on: 6.years.ago.to_date)
    assert messages(:tip).any? { |m| m.include?("signed over five years ago") }
  end
end
