require "rails_helper"

RSpec.describe "OutreachEmails", type: :request do
  let(:user)       { create(:user) }
  let(:other_user) { create(:user) }
  let(:lead)       { create(:lead, user: user) }
  let(:email)      { create(:outreach_email, lead: lead) }

  describe "GET /outreach_emails/:id" do
    it "redirects to sign in when unauthenticated" do
      get outreach_email_path(email)
      expect(response).to redirect_to(sign_in_path)
    end

    it "returns 200 for the owner" do
      sign_in_as(user)
      get outreach_email_path(email)
      expect(response).to have_http_status(:ok)
    end

    it "returns 404 for an email belonging to a different user's lead" do
      sign_in_as(other_user)
      get outreach_email_path(email)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /outreach_emails/:id" do
    it "destroys the record and redirects to the parent lead" do
      sign_in_as(user)
      email_to_delete = create(:outreach_email, lead: lead)
      expect {
        delete outreach_email_path(email_to_delete)
      }.to change(OutreachEmail, :count).by(-1)
      expect(response).to redirect_to(lead_path(lead))
    end

    it "returns 404 when trying to delete another user's email" do
      email  # force creation before entering the change block
      sign_in_as(other_user)
      expect {
        delete outreach_email_path(email)
      }.not_to change(OutreachEmail, :count)
      expect(response).to have_http_status(:not_found)
    end
  end
end
