class ConfirmationsController < ApplicationController
  def confirm_email
    @user = User.find_signed(params[:confirmation_token])

    if @user.present?
      @user.confirm!
      redirect_to root_path, notice: "Your account has been confirmed."
    end
  end
end
