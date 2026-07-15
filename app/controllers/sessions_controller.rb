class SessionsController < ApplicationController
  skip_before_action :require_login

  # Slow down password brute-forcing. Counted per IP by Rails' built-in
  # limiter; responds 429 Too Many Requests once exceeded.
  rate_limit to: 10, within: 3.minutes, only: :create

  def new; end

  def create
    @user = User.find_by(email: params[:user][:email].downcase)
    if @user
      if @user.authenticate(params[:user][:password])
        reset_session
        session[:current_user_id] = @user.id
        redirect_to dashboard_path, notice: "Signed in."
      else
        flash.now[:alert] = "Incorrect email or password."
        render :new, status: :unprocessable_entity
      end
    else
      flash.now[:alert] = "Incorrect email or password."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    redirect_to root_url
  end
end
