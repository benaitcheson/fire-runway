class AssetContribution < ApplicationRecord
  belongs_to :user_asset

  validates :occurred_on, presence: true
  validates :amount_cents, presence: true, numericality: { other_than: 0, only_integer: true }
  validate :not_in_future

  scope :chronological, -> { order(:occurred_on, :id) }
  scope :on_or_before, ->(date) { where(occurred_on: ..date) }

  # Money in dollars for forms; negative = withdrawal.
  def amount
    amount_cents && amount_cents / 100.0
  end

  def amount=(dollars)
    self.amount_cents = (dollars.to_f * 100).round
  end

  private

  def not_in_future
    errors.add(:occurred_on, "can't be in the future") if occurred_on.present? && occurred_on > Date.current
  end
end
