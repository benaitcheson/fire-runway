class AssetValuation < ApplicationRecord
  belongs_to :user_asset

  validates :valued_on, presence: true, uniqueness: { scope: :user_asset_id }
  validates :value_cents, presence: true, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validate :not_in_future

  scope :chronological, -> { order(:valued_on, :id) }
  scope :on_or_before, ->(date) { where(valued_on: ..date) }

  def value
    value_cents && value_cents / 100.0
  end

  def value=(dollars)
    self.value_cents = (dollars.to_f * 100).round
  end

  private

  def not_in_future
    errors.add(:valued_on, "can't be in the future") if valued_on.present? && valued_on > Date.current
  end
end
