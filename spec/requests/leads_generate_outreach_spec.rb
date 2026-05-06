require "rails_helper"

RSpec.describe "Leads#generate_outreach", type: :request do
  let(:user)           { create(:user) }
  let(:other_user)     { create(:user) }
  let(:seller_profile) { create(:seller_profile, user: user) }

  let(:valid_raw) do
    {
      research_summary: "Acme Corp recently raised a $10M Series A.",
      sources:          ["https://techcrunch.com/acme-series-a"],
      subject:          "Congrats on the Series A",
      body:             "Hi Jordan,\n\nSaw the Series A announcement..."
    }.to_json
  end

  let(:stub_result) do
    {
      raw:   valid_raw,
      trace: [{ tool: "search_web", args: { "query" => "Acme Corp funding" }, result: "Acme raised $10M..." }]
    }
  end

  before do
    allow(GeminiService).to receive(:generate_with_tools).and_return(stub_result)
  end

  describe "POST /leads/:id/generate_outreach" do
    context "when unauthenticated" do
      it "redirects to sign in" do
        lead = create(:lead, user: user)
        post generate_outreach_lead_path(lead),
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response).to redirect_to(sign_in_path)
      end
    end

    context "when the lead belongs to another user" do
      it "returns 404" do
        lead = create(:lead, user: user)
        sign_in_as(other_user)
        post generate_outreach_lead_path(lead),
             params:  { angle: "value" },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when no seller profile exists" do
      it "returns a Turbo Stream warning without calling Gemini" do
        lead = create(:lead, user: user)
        sign_in_as(user)
        post generate_outreach_lead_path(lead),
             params:  { angle: "value" },
             as:      :json,
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(GeminiService).not_to have_received(:generate_with_tools)
        expect(response.body).to include("seller profile")
      end
    end

    context "with a seller profile present" do
      before { seller_profile }

      it "calls generate_with_tools with the startup template for startup company_size" do
        lead = create(:lead, user: user, company_size: "startup")
        sign_in_as(user)
        post generate_outreach_lead_path(lead),
             params:  { angle: "value" },
             as:      :json,
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(GeminiService).to have_received(:generate_with_tools)
          .with(hash_including(template: "collectivecrm_outreach_startup_v1"))
      end

      it "calls generate_with_tools with the startup template for smb company_size" do
        lead = create(:lead, user: user, company_size: "smb")
        sign_in_as(user)
        post generate_outreach_lead_path(lead),
             params:  { angle: "value" },
             as:      :json,
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(GeminiService).to have_received(:generate_with_tools)
          .with(hash_including(template: "collectivecrm_outreach_startup_v1"))
      end

      it "calls generate_with_tools with the enterprise template for enterprise company_size" do
        lead = create(:lead, :enterprise, user: user)
        sign_in_as(user)
        post generate_outreach_lead_path(lead),
             params:  { angle: "problem" },
             as:      :json,
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(GeminiService).to have_received(:generate_with_tools)
          .with(hash_including(template: "collectivecrm_outreach_enterprise_v1"))
      end

      it "creates an OutreachEmail record on success" do
        lead = create(:lead, user: user)
        sign_in_as(user)
        expect {
          post generate_outreach_lead_path(lead),
               params:  { angle: "value" },
               as:      :json,
               headers: { "Accept" => "text/vnd.turbo-stream.html" }
        }.to change(OutreachEmail, :count).by(1)
      end

      it "stores agent_trace JSON on the created OutreachEmail" do
        lead = create(:lead, user: user)
        sign_in_as(user)
        post generate_outreach_lead_path(lead),
             params:  { angle: "value" },
             as:      :json,
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
        trace = JSON.parse(OutreachEmail.last.agent_trace)
        expect(trace.first["tool"]).to eq("search_web")
      end

      it "stores sources on the created OutreachEmail" do
        lead = create(:lead, user: user)
        sign_in_as(user)
        post generate_outreach_lead_path(lead),
             params:  { angle: "value" },
             as:      :json,
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(OutreachEmail.last.sources).to include("techcrunch.com")
      end

      it "returns a Turbo Stream response on success" do
        lead = create(:lead, user: user)
        sign_in_as(user)
        post generate_outreach_lead_path(lead),
             params:  { angle: "value" },
             as:      :json,
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      end

      it "returns an inline error Turbo Stream when GeminiService raises GeminiError" do
        allow(GeminiService).to receive(:generate_with_tools)
          .and_raise(GeminiService::GeminiError, "API error")
        lead = create(:lead, user: user)
        sign_in_as(user)
        post generate_outreach_lead_path(lead),
             params:  { angle: "value" },
             as:      :json,
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(OutreachEmail.count).to eq(0)
      end

      it "returns an inline error Turbo Stream when budget is exceeded" do
        allow(GeminiService).to receive(:generate_with_tools)
          .and_raise(GeminiService::BudgetExceededError, "Budget exceeded")
        lead = create(:lead, user: user)
        sign_in_as(user)
        post generate_outreach_lead_path(lead),
             params:  { angle: "value" },
             as:      :json,
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response).to have_http_status(:ok)
        expect(OutreachEmail.count).to eq(0)
      end
    end
  end
end
