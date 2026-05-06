class SellerProfilesController < ApplicationController
  def edit
    @seller_profile = current_user.seller_profile || SellerProfile.new
  end

  def update
    @seller_profile = current_user.seller_profile || SellerProfile.new(user: current_user)
    if @seller_profile.update(seller_profile_params)
      redirect_to dashboard_path, notice: "Product context saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def seller_profile_params
    params.require(:seller_profile).permit(:product_name, :product_description)
  end
end
