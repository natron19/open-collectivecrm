FactoryBot.define do
  factory :outreach_email do
    lead
    angle            { "value" }
    subject          { "Great opportunity for your company" }
    body             { "Hi there, I wanted to reach out about something specific I found..." }
    research_summary { "The agent found recent funding news for this company." }
    sources          { "https://example.com/news" }
    agent_trace      { [ { tool: "search_web", args: { query: "Acme Corp funding" }, result: "Found Series A..." } ].to_json }
    gemini_raw       { '{"research_summary":"Recent funding news.","subject":"Great opportunity","body":"Hi there...","sources":["https://example.com/news"]}' }

    trait :problem do
      angle { "problem" }
    end

    trait :referral do
      angle { "referral" }
    end
  end
end
