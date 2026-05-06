require "rails_helper"

RSpec.describe GeminiService do
  let(:user)     { create(:user) }
  let(:template) { create(:ai_template) }

  # Stub call_gemini to avoid needing GEMINI_API_KEY or a real HTTP call.
  def stub_gemini_success(text: "Hello, World!", prompt_tokens: 100, response_tokens: 50)
    allow_any_instance_of(GeminiService).to receive(:call_gemini)
      .and_return([text, prompt_tokens, response_tokens])
  end

  def stub_gemini_timeout
    allow_any_instance_of(GeminiService).to receive(:call_gemini)
      .and_raise(Timeout::Error)
  end

  def stub_gemini_api_error(message = "API failure")
    allow_any_instance_of(GeminiService).to receive(:call_gemini)
      .and_raise(StandardError, message)
  end

  # Stubs the private HTTP method used by generate_with_tools.
  # Returns a single-turn response with final text (no function calls).
  def stub_gemini_with_tools_success(text: '{"research_summary":"Found news.","sources":["https://example.com"],"subject":"Hi","body":"Hello"}')
    fake_body = {
      "candidates"    => [{ "content" => { "parts" => [{ "text" => text }] } }],
      "usageMetadata" => { "promptTokenCount" => 100, "candidatesTokenCount" => 50 }
    }
    fake_response = instance_double(Faraday::Response, success?: true, body: fake_body)
    allow_any_instance_of(GeminiService).to receive(:call_gemini_with_tools)
      .and_return(fake_response)
  end

  describe ".generate_with_tools" do
    context "when template does not exist" do
      it "raises ActiveRecord::RecordNotFound" do
        expect {
          GeminiService.generate_with_tools(template: "nonexistent_v999", user: user)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when gatekeeper blocks the input" do
      before do
        allow(AiGatekeeper).to receive(:check!)
          .and_raise(GeminiService::GatekeeperError, "Blocked input")
      end

      it "calls AiGatekeeper.check! before the API call" do
        expect(AiGatekeeper).to receive(:check!)
          .and_raise(GeminiService::GatekeeperError, "Blocked input")
        GeminiService.generate_with_tools(template: template.name, user: user) rescue nil
      end

      it "writes a gatekeeper_blocked LlmRequest" do
        expect {
          GeminiService.generate_with_tools(template: template.name, user: user) rescue nil
        }.to change(LlmRequest, :count).by(1)
        expect(LlmRequest.last.status).to eq("gatekeeper_blocked")
      end
    end

    context "when budget is exceeded" do
      before do
        allow(AiBudgetChecker).to receive(:check!)
          .and_raise(GeminiService::BudgetExceededError, "Limit reached")
      end

      it "calls AiBudgetChecker.check! before the API call" do
        expect(AiBudgetChecker).to receive(:check!)
          .and_raise(GeminiService::BudgetExceededError, "Limit reached")
        GeminiService.generate_with_tools(template: template.name, user: user) rescue nil
      end

      it "writes a budget_exceeded LlmRequest" do
        expect {
          GeminiService.generate_with_tools(template: template.name, user: user) rescue nil
        }.to change(LlmRequest, :count).by(1)
        expect(LlmRequest.last.status).to eq("budget_exceeded")
      end
    end

    context "when Gemini returns a successful text response" do
      before { stub_gemini_with_tools_success }

      it "returns a hash with :raw and :trace keys" do
        result = GeminiService.generate_with_tools(template: template.name, user: user)
        expect(result).to include(:raw, :trace)
      end

      it ":raw contains the response text" do
        result = GeminiService.generate_with_tools(template: template.name, user: user)
        expect(result[:raw]).to include("Found news.")
      end

      it ":trace is an array" do
        result = GeminiService.generate_with_tools(template: template.name, user: user)
        expect(result[:trace]).to be_an(Array)
      end

      it "writes a success LlmRequest with token counts" do
        expect {
          GeminiService.generate_with_tools(template: template.name, user: user)
        }.to change(LlmRequest, :count).by(1)

        log = LlmRequest.last
        expect(log.status).to eq("success")
        expect(log.prompt_token_count).to eq(100)
        expect(log.response_token_count).to eq(50)
        expect(log.duration_ms).to be_a(Integer)
      end

      it "denormalizes template_name onto the log row" do
        GeminiService.generate_with_tools(template: template.name, user: user)
        expect(LlmRequest.last.template_name).to eq(template.name)
      end
    end
  end

  describe ".generate" do
    context "when template does not exist" do
      it "raises ActiveRecord::RecordNotFound" do
        expect {
          GeminiService.generate(template: "nonexistent_v999", user: user)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when gatekeeper blocks the input" do
      before do
        allow(AiGatekeeper).to receive(:check!)
          .and_raise(GeminiService::GatekeeperError, "Blocked input")
      end

      it "raises GatekeeperError" do
        expect {
          GeminiService.generate(template: template.name, user: user)
        }.to raise_error(GeminiService::GatekeeperError)
      end

      it "writes a gatekeeper_blocked LlmRequest" do
        expect {
          GeminiService.generate(template: template.name, user: user) rescue nil
        }.to change(LlmRequest, :count).by(1)

        expect(LlmRequest.last.status).to eq("gatekeeper_blocked")
        expect(LlmRequest.last.template_name).to eq(template.name)
      end
    end

    context "when budget is exceeded" do
      before do
        allow(AiBudgetChecker).to receive(:check!)
          .and_raise(GeminiService::BudgetExceededError, "Limit reached")
      end

      it "raises BudgetExceededError" do
        expect {
          GeminiService.generate(template: template.name, user: user)
        }.to raise_error(GeminiService::BudgetExceededError)
      end

      it "writes a budget_exceeded LlmRequest" do
        expect {
          GeminiService.generate(template: template.name, user: user) rescue nil
        }.to change(LlmRequest, :count).by(1)

        expect(LlmRequest.last.status).to eq("budget_exceeded")
      end
    end

    context "when the API call times out" do
      before { stub_gemini_timeout }

      it "raises TimeoutError" do
        expect {
          GeminiService.generate(template: template.name, user: user)
        }.to raise_error(GeminiService::TimeoutError)
      end

      it "writes a timeout LlmRequest" do
        expect {
          GeminiService.generate(template: template.name, user: user) rescue nil
        }.to change(LlmRequest, :count).by(1)

        expect(LlmRequest.last.status).to eq("timeout")
      end
    end

    context "when Gemini returns a successful response" do
      before { stub_gemini_success }

      it "returns the response text" do
        result = GeminiService.generate(template: template.name, user: user)
        expect(result).to eq("Hello, World!")
      end

      it "writes a success LlmRequest with token counts and duration" do
        expect {
          GeminiService.generate(template: template.name, user: user)
        }.to change(LlmRequest, :count).by(1)

        log = LlmRequest.last
        expect(log.status).to eq("success")
        expect(log.prompt_token_count).to eq(100)
        expect(log.response_token_count).to eq(50)
        expect(log.duration_ms).to be_a(Integer)
        expect(log.cost_estimate_cents).to be_present
      end

      it "denormalizes template_name onto the log row" do
        GeminiService.generate(template: template.name, user: user)
        expect(LlmRequest.last.template_name).to eq(template.name)
      end
    end
  end
end
