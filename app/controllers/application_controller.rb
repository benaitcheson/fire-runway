class ApplicationController < ActionController::Base
  include Authenticated

  before_action :require_login

  private

  def require_login
    redirect_to login_path, alert: "Please log in first." unless user_signed_in?
  end
end
