require "rails_helper"

RSpec.describe "Leads", type: :request do
  let(:user)       { create(:user) }
  let(:other_user) { create(:user) }
  let(:lead)       { create(:lead, user: user) }

  describe "GET /leads/new" do
    it "redirects to sign in when unauthenticated" do
      get new_lead_path
      expect(response).to redirect_to(sign_in_path)
    end

    it "returns 200 when signed in" do
      sign_in_as(user)
      get new_lead_path
      expect(response).to have_http_status(:ok)
    end

    it "pre-fills the stage when passed as a param" do
      sign_in_as(user)
      get new_lead_path(stage: "qualified")
      expect(response.body).to include("qualified")
    end
  end

  describe "POST /leads" do
    let(:valid_params) do
      { lead: { first_name: "Alex", last_name: "Smith", company: "Acme",
                company_size: "startup", stage: "prospect" } }
    end

    it "redirects to sign in when unauthenticated" do
      post leads_path, params: valid_params
      expect(response).to redirect_to(sign_in_path)
    end

    it "creates a lead scoped to the current user" do
      sign_in_as(user)
      expect {
        post leads_path, params: valid_params
      }.to change(Lead, :count).by(1)
      expect(Lead.last.user).to eq(user)
    end

    it "redirects to the lead show page on success" do
      sign_in_as(user)
      post leads_path, params: valid_params
      expect(response).to redirect_to(lead_path(Lead.last))
    end

    it "re-renders new with errors on invalid params" do
      sign_in_as(user)
      post leads_path, params: { lead: { first_name: "" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /leads/:id" do
    it "returns 200 for the owner" do
      sign_in_as(user)
      get lead_path(lead)
      expect(response).to have_http_status(:ok)
    end

    it "returns 404 for a lead belonging to a different user" do
      sign_in_as(other_user)
      get lead_path(lead)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /leads/:id/edit" do
    it "returns 200 for the owner" do
      sign_in_as(user)
      get edit_lead_path(lead)
      expect(response).to have_http_status(:ok)
    end

    it "returns 404 for a different user" do
      sign_in_as(other_user)
      get edit_lead_path(lead)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /leads/:id" do
    it "updates stage and returns Turbo Stream when requested" do
      sign_in_as(user)
      patch lead_path(lead),
            params: { lead: { stage: "contacted" } },
            headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(lead.reload.stage).to eq("contacted")
    end

    it "redirects to the lead page on HTML update" do
      sign_in_as(user)
      patch lead_path(lead), params: { lead: { stage: "qualified" } }
      expect(response).to redirect_to(lead_path(lead))
    end
  end

  describe "DELETE /leads/:id" do
    it "destroys the lead and redirects to dashboard" do
      sign_in_as(user)
      lead_to_delete = create(:lead, user: user)
      expect {
        delete lead_path(lead_to_delete)
      }.to change(Lead, :count).by(-1)
      expect(response).to redirect_to(dashboard_path)
    end
  end
end
