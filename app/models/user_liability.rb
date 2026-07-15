# == Schema Information
#
# Table name: user_liabilities
#
#  id               :bigint           not null, primary key
#  item_name        :string           not null
#  amount_cents     :integer          not null
#  amount_currency  :string           default("AUD"), not null
#  user_id          :integer          not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_user_liabilities_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class UserLiability < ApplicationRecord
  belongs_to :user
  
  validates :item_name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :amount_cents, presence: true, numericality: { greater_than: 0 }
  validates :amount_currency, presence: true, inclusion: { in: %w[AUD USD EUR GBP JPY] }
  validates :interest_rate, numericality: { greater_than_or_equal_to: 0, less_than: 100 }
  validates :minimum_monthly_payment_cents, numericality: { greater_than_or_equal_to: 0, only_integer: true }

  # Minimum payment exposed in dollars for forms.
  def minimum_monthly_payment
    minimum_monthly_payment_cents / 100.0
  end

  def minimum_monthly_payment=(dollars)
    self.minimum_monthly_payment_cents = (dollars.to_f * 100).round
  end
end
