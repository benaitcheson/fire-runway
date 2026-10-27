# Someone who inherits under the will plan: a share of the residue (what is
# left after debts and specific gifts) and any assets gifted to them directly.
class WillBeneficiary < ApplicationRecord
  FALLBACKS = {
    "their_children" => "Their children, in equal shares",
    "others" => "The other beneficiaries",
    "named" => "Someone else (named below)"
  }.freeze

  belongs_to :will_plan
  has_many :gifts, class_name: "WillAssetInstruction", foreign_key: :will_beneficiary_id,
           dependent: :nullify, inverse_of: :will_beneficiary

  validates :name, presence: true, length: { maximum: 100 }
  validates :relationship, :fallback_name, length: { maximum: 100 }
  validates :residue_share_pct, numericality: { in: 0..100 }
  validates :fallback, inclusion: { in: FALLBACKS.keys }
  validates :fallback_name, presence: { message: "is needed when their share goes to someone else" },
                            if: -> { fallback == "named" }

  normalizes :name, :relationship, :fallback_name, with: ->(value) { value.strip.presence }

  def label
    relationship ? "#{name} (#{relationship})" : name
  end

  def fallback_description
    fallback == "named" ? fallback_name : FALLBACKS.fetch(fallback)
  end
end
