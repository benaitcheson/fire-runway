class WillPlansController < ApplicationController
  before_action :load_plan

  # GET /will
  def show; end

  # PATCH /will
  def update
    if @plan.update(will_plan_params)
      redirect_to will_path, notice: "Will plan saved."
    else
      flash.now[:alert] = "Will plan not saved. Fix the errors below and try again."
      render :show, status: :unprocessable_entity
    end
  end

  # GET /will/summary: a printable page to take to whoever writes the will.
  def summary; end

  private

  def load_plan
    @plan = current_user.will
    @estate = WillPlanner::Estate.new(@plan)
  end

  # Nested records are scoped by Rails to this plan; user_asset_id and
  # will_beneficiary_id are checked against the plan's owner by validations.
  def will_plan_params
    params.fetch(:will_plan, {}).permit(
      :state, :executor_name, :executor_relationship, :backup_executor_name, :guardian_name,
      :backup_guardian_name, :super_nomination, :super_nominee, :funeral_wishes, :other_wishes,
      :will_status, :signed_on, :stored_at,
      beneficiaries_attributes: [:id, :name, :relationship, :residue_share_pct, :fallback, :fallback_name, :_destroy],
      asset_instructions_attributes: [:id, :user_asset_id, :ownership, :owned_share_pct, :will_beneficiary_id],
      liability_instructions_attributes: [:id, :user_liability_id, :secured_asset_id]
    )
  end
end
