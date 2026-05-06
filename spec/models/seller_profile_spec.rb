require "rails_helper"

RSpec.describe SellerProfile, type: :model do
  describe "validations" do
    it "is valid with all required fields" do
      expect(build(:seller_profile)).to be_valid
    end

    it "is invalid without product_name" do
      expect(build(:seller_profile, product_name: nil)).not_to be_valid
    end

    it "is invalid without product_description" do
      expect(build(:seller_profile, product_description: nil)).not_to be_valid
    end

    it "is invalid if product_description exceeds 500 characters" do
      expect(build(:seller_profile, product_description: "a" * 501)).not_to be_valid
    end

    it "enforces one profile per user" do
      user = create(:user)
      create(:seller_profile, user: user)
      expect(build(:seller_profile, user: user)).not_to be_valid
    end
  end
end
