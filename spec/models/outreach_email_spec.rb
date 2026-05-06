require "rails_helper"

RSpec.describe OutreachEmail, type: :model do
  describe "validations" do
    it "is valid with required fields" do
      expect(build(:outreach_email)).to be_valid
    end

    it "is invalid without angle" do
      expect(build(:outreach_email, angle: nil)).not_to be_valid
    end

    it "is invalid with an unrecognized angle" do
      expect(build(:outreach_email, angle: "aggressive")).not_to be_valid
    end
  end

  describe "associations" do
    it "belongs to a lead" do
      expect(build(:outreach_email).lead).to be_a(Lead)
    end
  end
end
