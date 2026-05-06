require "faraday"
require "json"

class PerplexityService
  BASE_URL  = "https://api.perplexity.ai/chat/completions"
  MAX_CHARS = 1500
  MODEL     = "sonar"

  def self.search(query)
    new.search(query)
  end

  def search(query)
    return placeholder_response(query) if api_key.blank?

    http = Faraday.new do |conn|
      conn.request  :json
      conn.response :json
      conn.adapter  Faraday.default_adapter
    end

    response = http.post(BASE_URL) do |req|
      req.headers["Authorization"] = "Bearer #{api_key}"
      req.body = {
        model:    MODEL,
        messages: [{ role: "user", content: query }]
      }
    end

    parse_response(response.body)
  rescue => e
    "Search failed: #{e.message}"
  end

  private

  def api_key = ENV.fetch("PERPLEXITY_API_KEY", "")

  def parse_response(data)
    text      = data.dig("choices", 0, "message", "content").to_s
    citations = Array(data["citations"]).first(5)
    result    = citations.any? ? "#{text}\nSources: #{citations.join(', ')}" : text
    result.truncate(MAX_CHARS)
  end

  def placeholder_response(query)
    "No PERPLEXITY_API_KEY configured. Cannot search for: #{query}"
  end
end
