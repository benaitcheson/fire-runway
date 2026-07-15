class AssetContributionsController < ApplicationController
  before_action :set_asset

  def create
    contribution = @asset.asset_contributions.build(contribution_params)
    if contribution.save
      redirect_to user_asset_path(@asset), notice: "Contribution recorded."
    else
      redirect_to user_asset_path(@asset), alert: contribution.errors.full_messages.to_sentence
    end
  end

  def destroy
    @asset.asset_contributions.find(params[:id]).destroy
    redirect_to user_asset_path(@asset)
  end

  private

  def set_asset
    @asset = current_user.user_assets.find(params[:user_asset_id])
  end

  def contribution_params
    params.require(:asset_contribution).permit(:occurred_on, :amount)
  end
end
