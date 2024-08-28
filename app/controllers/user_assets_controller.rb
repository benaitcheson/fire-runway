class UserAssetsController < ApplicationController
  before_action :set_user_asset, only: [:show, :edit, :update, :destroy]

  # GET /user_assets
  def index
    @user_assets = current_user.user_assets
  end

  # GET /user_assets/1
  def show
  end

  # GET /user_assets/new
  def new
    @user_asset = UserAsset.new
  end

  # POST /user_assets
  def create
    @user_asset = current_user.user_assets.build(user_asset_params)

    if @user_asset.save
      redirect_to @user_asset, notice: 'User asset was successfully created.'
    else
      render :new
    end
  end

  # GET /user_assets/1/edit
  def edit
  end

  # PUT /user_assets/1
  def update
    if @user_asset.update(user_asset_params)
      redirect_to @user_asset, notice: "User asset was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /user_assets/1
  def destroy
    @user_asset.destroy
    redirect_to user_assets_url, notice: "User asset was successfully destroyed."
  end

  private

    def set_user_asset
      @user_asset = current_user.user_assets.find(params[:id])
    end

    def user_asset_params
      params.require(:user_asset).permit(:item_name, :purchase_price_cents, :purchase_price_currency, :purchase_date)
    end
end
