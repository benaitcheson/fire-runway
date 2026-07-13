class UsersController < ApplicationController
  skip_before_action :require_login

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    if @user.save
      # @user.send_confirmation_email!
      redirect_to root_path, notice: 'A confirmation email has been sent to your registered email.'
    else
      render :new, status: :unprocessable_entity, notice: @user.errors.full_messages.join(', ')
    end
  end

  private

    def user_params
      params.require(:user).permit(:email, :password, :password_confirmation)
    end
end
