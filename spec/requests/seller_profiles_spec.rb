require "rails_helper"

RSpec.describe "SellerProfiles", type: :request do
  let(:user)       { create(:user) }
  let(:other_user) { create(:user) }

  describe "GET /seller_profile/edit" do
    it "redirects to sign in when unauthenticated" do
      get edit_seller_profile_path
      expect(response).to redirect_to(sign_in_path)
    end

    it "returns 200 when signed in" do
      sign_in_as(user)
      get edit_seller_profile_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /seller_profile" do
    let(:valid_params) do
      { seller_profile: { product_name: "MyProduct", product_description: "It does great things." } }
    end

    it "redirects to sign in when unauthenticated" do
      patch seller_profile_path, params: valid_params
      expect(response).to redirect_to(sign_in_path)
    end

    it "creates a seller profile for the current user when none exists" do
      sign_in_as(user)
      expect {
        patch seller_profile_path, params: valid_params
      }.to change(SellerProfile, :count).by(1)
      expect(SellerProfile.last.user).to eq(user)
    end

    it "updates an existing seller profile" do
      profile = create(:seller_profile, user: user, product_name: "OldName")
      sign_in_as(user)
      patch seller_profile_path, params: { seller_profile: { product_name: "NewName", product_description: profile.product_description } }
      expect(profile.reload.product_name).to eq("NewName")
    end

    it "redirects to dashboard on success" do
      sign_in_as(user)
      patch seller_profile_path, params: valid_params
      expect(response).to redirect_to(dashboard_path)
    end

    it "does not create a profile for another user" do
      sign_in_as(user)
      patch seller_profile_path, params: valid_params
      expect(SellerProfile.find_by(user: other_user)).to be_nil
    end

    it "re-renders edit with errors on invalid params" do
      sign_in_as(user)
      patch seller_profile_path, params: { seller_profile: { product_name: "", product_description: "" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
