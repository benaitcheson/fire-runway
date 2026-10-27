# The will planner: who is in charge, who gets what, and which assets pass
# outside the will entirely. A worksheet to take to a lawyer, the Public
# Trustee or a will kit; it is not a will. One per user.
class WillPlan < ApplicationRecord
  STATES = {
    "NSW" => "New South Wales", "VIC" => "Victoria", "QLD" => "Queensland",
    "WA" => "Western Australia", "SA" => "South Australia", "TAS" => "Tasmania",
    "ACT" => "Australian Capital Territory", "NT" => "Northern Territory"
  }.freeze
  # Where the state's public trustee goes by another name.
  PUBLIC_TRUSTEE_NAMES = {
    "NSW" => "NSW Trustee & Guardian",
    "VIC" => "State Trustees",
    "ACT" => "Public Trustee and Guardian"
  }.freeze
  SUPER_NOMINATIONS = {
    "none" => "No nomination",
    "non_binding" => "Non-binding nomination (the fund trustee decides)",
    "binding_lapsing" => "Binding nomination that lapses (usually after 3 years)",
    "binding_non_lapsing" => "Binding non-lapsing nomination",
    "reversionary" => "Reversionary pension",
    "unsure" => "Not sure"
  }.freeze
  WILL_STATUSES = {
    "not_started" => "Not started",
    "planning" => "Planning on this page",
    "drafted" => "Drafted, not yet signed",
    "signed" => "Signed and witnessed"
  }.freeze

  belongs_to :user
  has_many :beneficiaries, -> { order(:created_at, :id) }, class_name: "WillBeneficiary",
           dependent: :destroy, inverse_of: :will_plan
  has_many :asset_instructions, class_name: "WillAssetInstruction", dependent: :destroy,
           inverse_of: :will_plan
  has_many :liability_instructions, class_name: "WillLiabilityInstruction", dependent: :destroy,
           inverse_of: :will_plan

  # A blank "add a beneficiary" row is ignored rather than failing validation.
  accepts_nested_attributes_for :beneficiaries, allow_destroy: true,
                                reject_if: ->(attrs) { attrs["id"].blank? && attrs["name"].blank? }
  accepts_nested_attributes_for :asset_instructions
  accepts_nested_attributes_for :liability_instructions

  validates :state, inclusion: { in: STATES.keys }, allow_blank: true
  validates :super_nomination, inclusion: { in: SUPER_NOMINATIONS.keys }, allow_blank: true
  validates :will_status, inclusion: { in: WILL_STATUSES.keys }
  validates :executor_name, :executor_relationship, :backup_executor_name, :guardian_name,
            :backup_guardian_name, :super_nominee, :stored_at, length: { maximum: 100 }
  validates :funeral_wishes, :other_wishes, length: { maximum: 2000 }
  validate :signed_on_not_in_future

  normalizes :state, :executor_name, :executor_relationship, :backup_executor_name, :guardian_name,
             :backup_guardian_name, :super_nomination, :super_nominee, :funeral_wishes,
             :other_wishes, :stored_at, with: ->(value) { value.strip.presence }

  # A signed will answers the Profile's "Will in place" question.
  after_save :record_will_on_profile, if: -> { saved_change_to_will_status? && will_status == "signed" }

  def public_trustee_name
    PUBLIC_TRUSTEE_NAMES.fetch(state, "Public Trustee")
  end

  # Every one of the user's assets paired with its instruction, building a
  # default ("in my name only", into the residue) for assets not yet saved.
  def instructions_for_assets
    user.user_assets.includes(:asset_valuations, :asset_contributions).order(:item_name).map do |asset|
      asset_instructions.detect { |i| i.user_asset_id == asset.id } ||
        asset_instructions.build(user_asset: asset)
    end
  end

  # Validation messages for the form, with each nested record named rather
  # than Rails' "Beneficiaries name can't be blank".
  def error_messages
    own = errors.reject { |e| e.attribute.to_s.include?(".") }.map(&:full_message)
    people = beneficiaries.flat_map do |b|
      b.errors.full_messages.map { |m| "#{b.name || 'New beneficiary'}: #{m}" }
    end
    assets = asset_instructions.flat_map do |i|
      i.errors.map { |e| e.attribute == :base ? e.message : "#{i.user_asset&.item_name}: #{e.full_message}" }
    end
    debts = liability_instructions.flat_map do |i|
      i.errors.full_messages.map { |m| "#{i.user_liability&.item_name}: #{m}" }
    end
    (own + people + assets + debts).uniq
  end

  # Every debt paired with its instruction; unsaved ones default to unsecured.
  def instructions_for_liabilities
    user.user_liabilities.order(:item_name).map do |liability|
      liability_instructions.detect { |i| i.user_liability_id == liability.id } ||
        liability_instructions.build(user_liability: liability)
    end
  end

  def residue_share_total
    beneficiaries.reject(&:marked_for_destruction?).sum { |b| b.residue_share_pct.to_d }
  end

  private

  def signed_on_not_in_future
    errors.add(:signed_on, "can't be in the future") if signed_on.present? && signed_on > Date.current
  end

  def record_will_on_profile
    user.profile.update!(has_will: true)
  end
end
