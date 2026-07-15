class AssetValuationsController < ApplicationController
  before_action :set_asset

  def create
    valuation = @asset.asset_valuations.build(valuation_params)
    if valuation.save
      redirect_to user_asset_path(@asset), notice: "Valuation recorded."
    else
      redirect_to user_asset_path(@asset), alert: valuation.errors.full_messages.to_sentence
    end
  end

  def destroy
    @asset.asset_valuations.find(params[:id]).destroy
    redirect_to user_asset_path(@asset)
  end

  private

  def set_asset
    @asset = current_user.user_assets.find(params[:user_asset_id])
  end

  def valuation_params
    params.require(:asset_valuation).permit(:valued_on, :value)
  end
end
