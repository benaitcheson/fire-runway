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
end
