class ConfirmationsController < ApplicationController
  skip_before_action :require_login

  def confirm_email
    @user = User.find_signed(params[:confirmation_token])

    if @user.present?
      @user.confirm!
      redirect_to root_path, notice: "Your account has been confirmed."
    else
      redirect_to login_path, alert: "Invalid or expired confirmation link."
    end
  end
end
