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
end
