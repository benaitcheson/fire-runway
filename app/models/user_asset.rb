# == Schema Information
#
# Table name: user_assets
#
#  id                      :bigint           not null, primary key
#  item_name               :string           not null
#  purchase_price_cents    :integer          not null
#  purchase_price_currency :string           default("AUD"), not null
#  purchase_date           :date             not null
#  user_id                 :integer          not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#
# Indexes
#
#  index_user_assets_on_user_id  (user_id)
#

class UserAsset < ApplicationRecord
  belongs_to :user
  
  validates :item_name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :purchase_price_cents, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :purchase_price_currency, presence: true, inclusion: { in: %w[AUD USD EUR GBP JPY] }
  validates :purchase_date, presence: true
  
  validate :purchase_date_not_in_future
  
  private
  
  def purchase_date_not_in_future
    if purchase_date.present? && purchase_date > Date.today
      errors.add(:purchase_date, "can't be in the future")
    end
  end
end
