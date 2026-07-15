class UserLiabilitiesController < ApplicationController
  before_action :set_user_liability, only: [:show, :edit, :update, :destroy]

  # GET /user_liabilities
  def index
    @user_liabilities = current_user.user_liabilities
    @total_liabilities = @user_liabilities.sum(:amount_cents)
    @liability_timeline = current_user.liability_timeline
  end

  # GET /user_liabilities/1
  def show
  end

  # GET /user_liabilities/new
  def new
    @user_liability = UserLiability.new
  end

  # POST /user_liabilities
  def create
    @user_liability = current_user.user_liabilities.build(user_liability_params)

    if @user_liability.save
      redirect_to @user_liability, notice: 'User liability was successfully created.'
    else
      render :new
    end
  end

  # GET /user_liabilities/1/edit
  def edit
  end

  # PATCH/PUT /user_liabilities/1
  def update
    if @user_liability.update(user_liability_params)
      redirect_to @user_liability, notice: 'User liability was successfully updated.'
    else
      render :edit
    end
  end

  # DELETE /user_liabilities/1
  def destroy
    @user_liability.destroy
    redirect_to user_liabilities_url, notice: 'User liability was successfully destroyed.'
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_user_liability
    @user_liability = current_user.user_liabilities.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def user_liability_params
    params.require(:user_liability).permit(:item_name, :amount_cents, :amount_currency,
                                           :interest_rate, :minimum_monthly_payment)
  end
end
