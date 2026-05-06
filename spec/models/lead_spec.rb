require "rails_helper"

RSpec.describe Lead, type: :model do
  describe "validations" do
    it "is valid with all required fields" do
      expect(build(:lead)).to be_valid
    end

    it "is invalid without first_name" do
      expect(build(:lead, first_name: nil)).not_to be_valid
    end

    it "is invalid without last_name" do
      expect(build(:lead, last_name: nil)).not_to be_valid
    end

    it "is invalid without company" do
      expect(build(:lead, company: nil)).not_to be_valid
    end

    it "is invalid without company_size" do
      expect(build(:lead, company_size: nil)).not_to be_valid
    end

    it "is invalid without stage" do
      expect(build(:lead, stage: nil)).not_to be_valid
    end

    it "is invalid with an unrecognized company_size" do
      expect(build(:lead, company_size: "huge")).not_to be_valid
    end

    it "is invalid with an unrecognized stage" do
      expect(build(:lead, stage: "unknown")).not_to be_valid
    end

    it "is invalid with a malformed email" do
      expect(build(:lead, email: "not-an-email")).not_to be_valid
    end

    it "is valid with a blank email" do
      expect(build(:lead, email: "")).to be_valid
    end
  end

  describe "associations" do
    it "destroys associated outreach_emails when deleted" do
      lead = create(:lead)
      create(:outreach_email, lead: lead)
      expect { lead.destroy }.to change(OutreachEmail, :count).by(-1)
    end
  end
end
