# How one of the user's assets is held, and so whether the will can pass it
# on at all. Joint tenancy goes to the surviving owner and super, trusts and
# companies follow their own rules; only assets held solely, or a tenants in
# common share, form part of the estate. Those can be gifted to a beneficiary
# or, by default, fall into the residue.
class WillAssetInstruction < ApplicationRecord
  OWNERSHIPS = {
    "sole" => "In my name only",
    "tenants_in_common" => "Jointly, as tenants in common",
    "joint_tenants" => "Jointly, as joint tenants",
    "outside_will" => "Outside my will (super, a trust or a company)"
  }.freeze
  UNDER_WILL = %w[sole tenants_in_common].freeze

  belongs_to :will_plan
  belongs_to :user_asset
  belongs_to :will_beneficiary, optional: true, inverse_of: :gifts

  validates :ownership, inclusion: { in: OWNERSHIPS.keys }
  validates :user_asset_id, uniqueness: { scope: :will_plan_id }
  validates :owned_share_pct, numericality: { greater_than: 0, less_than: 100 },
                              if: -> { ownership == "tenants_in_common" }
  validate :asset_belongs_to_plan_owner
  validate :beneficiary_belongs_to_plan
  validate :gift_only_when_under_will

  def passes_under_will? = UNDER_WILL.include?(ownership)
  def gift? = will_beneficiary_id.present?

  # The fraction of the asset that forms part of the estate.
  def estate_fraction
    case ownership
    when "sole" then 1
    when "tenants_in_common" then owned_share_pct.to_d / 100
    else 0
    end
  end

  def value_cents
    user_asset.current_value_cents
  end

  def estate_value_cents
    (value_cents * estate_fraction).round
  end

  private

  def asset_belongs_to_plan_owner
    return if user_asset.nil? || will_plan.nil? || user_asset.user_id == will_plan.user_id

    errors.add(:user_asset, "is not yours")
  end

  def beneficiary_belongs_to_plan
    return if will_beneficiary.nil? || will_beneficiary.will_plan_id == will_plan_id

    errors.add(:will_beneficiary, "is not in this plan")
  end

  def gift_only_when_under_will
    return unless gift? && !passes_under_will?

    errors.add(:base, "#{user_asset&.item_name} passes outside your will " \
                      "(#{OWNERSHIPS[ownership].downcase}), so it can't be gifted in it")
  end
end
