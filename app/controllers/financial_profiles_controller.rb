class FinancialProfilesController < ApplicationController
  # GET /profile
  def show
    @profile = current_user.profile
  end

  # PATCH /profile
  def update
    @profile = current_user.profile
    if @profile.update(profile_params)
      redirect_to profile_path, notice: "Profile saved. The AI assistant will use it from now on."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  # Money fields arrive in dollars via the model's virtual accessors.
  def profile_params
    params.fetch(:financial_profile, {}).permit(*FinancialProfile::FIELDS.map(&:name))
  end
end
