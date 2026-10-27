# Which asset, if any, one of the user's debts is secured on. Across the
# Australian states a secured debt is paid out of the asset it is secured on
# before anything else (unless the will says otherwise), so a mortgage
# follows the house: to the surviving joint owner, or to whoever is gifted it.
class WillLiabilityInstruction < ApplicationRecord
  belongs_to :will_plan
  belongs_to :user_liability
  belongs_to :secured_asset, class_name: "UserAsset", optional: true

  validates :user_liability_id, uniqueness: { scope: :will_plan_id }
  validate :records_belong_to_plan_owner

  private

  def records_belong_to_plan_owner
    return if will_plan.nil?

    errors.add(:user_liability, "is not yours") if user_liability && user_liability.user_id != will_plan.user_id
    errors.add(:secured_asset, "is not yours") if secured_asset && secured_asset.user_id != will_plan.user_id
  end
end
