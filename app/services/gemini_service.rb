require "faraday"
require "json"

class GeminiService
  class GeminiError         < StandardError; end
  class GatekeeperError     < GeminiError;   end
  class BudgetExceededError < GeminiError;   end
  class TimeoutError        < GeminiError;   end
  class OutputGuardError    < GeminiError;   end
  class CrisisError         < GatekeeperError; end

  TIMEOUT_SECONDS       = ENV.fetch("AI_GLOBAL_TIMEOUT_SECONDS", "15").to_i
  AGENT_TIMEOUT_SECONDS = ENV.fetch("AI_AGENT_TIMEOUT_SECONDS", "60").to_i
  BASE_URL              = "https://generativelanguage.googleapis.com/v1beta"

  # trusted: true skips the user-input gatekeeper. Only for internal callers whose
  # prompt is not user input (the eval harness LLM judge). Still logged and output-guarded.
  def self.generate(template:, variables: {}, user: Current.user, trusted: false)
    new(template:, variables:, user:, trusted:).generate
  end

  def self.generate_with_tools(template:, variables: {}, user: Current.user, &progress_block)
    new(template:, variables:, user:).generate_with_tools(&progress_block)
  end

  def initialize(template:, variables: {}, user:, trusted: false)
    @template_name = template
    @variables     = variables
    @user          = user
    @trusted       = trusted
  end

  def generate
    ai_template     = AiTemplate.find_by!(name: @template_name)
    rendered_prompt = ai_template.interpolate(@variables)

    begin
      AiGatekeeper.check!(rendered_prompt, @user) unless @trusted
    rescue GatekeeperError => e
      LlmRequest.create!(
        user: @user, ai_template: ai_template, template_name: ai_template.name,
        status: "gatekeeper_blocked", error_message: e.message
      ) if @user
      raise
    end

    if @user
      begin
        AiBudgetChecker.check!(@user)
      rescue BudgetExceededError => e
        LlmRequest.create!(
          user: @user, ai_template: ai_template, template_name: ai_template.name,
          status: "budget_exceeded", error_message: e.message
        )
        raise
      end
    end

    log = LlmRequest.create!(
      user:          @user,
      ai_template:   ai_template,
      template_name: ai_template.name,
      status:        "pending"
    )

    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    begin
      response_text, prompt_tokens, response_tokens = call_gemini(ai_template, rendered_prompt)
      duration_ms = elapsed_ms(start_time)

      log.update!(
        status:               "success",
        prompt_token_count:   prompt_tokens,
        response_token_count: response_tokens,
        duration_ms:          duration_ms,
        cost_estimate_cents:  estimate_cost(prompt_tokens, response_tokens, ai_template.model)
      )

      check_output!(log, ai_template, response_text, rendered_prompt)
      response_text

    rescue Timeout::Error
      log.update!(
        status:        "timeout",
        duration_ms:   elapsed_ms(start_time),
        error_message: "Gemini call timed out after #{TIMEOUT_SECONDS}s"
      )
      raise TimeoutError, "The AI request timed out. Please try again."

    rescue GeminiError
      raise

    rescue => e
      api_body = e.respond_to?(:response) && e.response ? e.response[:body].to_s : ""
      log.update!(
        status:        "error",
        duration_ms:   elapsed_ms(start_time),
        error_message: (api_body.presence || e.message).truncate(500)
      )
      raise GeminiError, "An error occurred while generating a response."
    end
  end

  def generate_with_tools(&progress_block)
    ai_template     = AiTemplate.find_by!(name: @template_name)
    rendered_prompt = ai_template.interpolate(@variables)

    begin
      AiGatekeeper.check!(rendered_prompt, @user)
    rescue GatekeeperError => e
      LlmRequest.create!(
        user: @user, ai_template: ai_template, template_name: ai_template.name,
        status: "gatekeeper_blocked", error_message: e.message
      ) if @user
      raise
    end

    if @user
      begin
        AiBudgetChecker.check!(@user)
      rescue BudgetExceededError => e
        LlmRequest.create!(
          user: @user, ai_template: ai_template, template_name: ai_template.name,
          status: "budget_exceeded", error_message: e.message
        )
        raise
      end
    end

    log = LlmRequest.create!(
      user:          @user,
      ai_template:   ai_template,
      template_name: ai_template.name,
      status:        "pending"
    )

    full_prompt = [ai_template.system_prompt.presence, rendered_prompt].compact.join("\n\n")
    contents    = [{ role: "user", parts: [{ text: full_prompt }] }]
    tools       = build_tool_definitions
    trace       = []
    start_time  = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    begin
      result_text, prompt_tokens, response_tokens = run_agent_loop(
        ai_template, contents, tools, trace, &progress_block
      )
      duration_ms = elapsed_ms(start_time)

      log.update!(
        status:               "success",
        prompt_token_count:   prompt_tokens,
        response_token_count: response_tokens,
        duration_ms:          duration_ms,
        cost_estimate_cents:  estimate_cost(prompt_tokens, response_tokens, ai_template.model)
      )

      check_output!(log, ai_template, result_text, rendered_prompt)
      { raw: result_text, trace: trace }

    rescue Timeout::Error
      log.update!(
        status:        "timeout",
        duration_ms:   elapsed_ms(start_time),
        error_message: "Gemini agent timed out after #{AGENT_TIMEOUT_SECONDS}s"
      )
      raise TimeoutError, "The AI request timed out. Please try again."

    rescue GeminiError
      raise

    rescue => e
      api_body = e.respond_to?(:response) && e.response ? e.response[:body].to_s : ""
      log.update!(
        status:        "error",
        duration_ms:   elapsed_ms(start_time),
        error_message: (api_body.presence || e.message).truncate(500)
      )
      raise GeminiError, "An error occurred while generating a response."
    end
  end

  private

  MAX_AGENT_ROUNDS = 5

  def check_output!(log, ai_template, response_text, rendered_prompt)
    AiOutputGuard.check!(response_text, template: ai_template, input: rendered_prompt)
  rescue OutputGuardError => e
    log.update!(status: "output_blocked", error_message: e.message)
    raise
  end

  def run_agent_loop(ai_template, contents, tools, trace, &progress_block)
    prompt_tokens   = 0
    response_tokens = 0

    Timeout.timeout(AGENT_TIMEOUT_SECONDS) do
      MAX_AGENT_ROUNDS.times do
        response = call_gemini_with_tools(ai_template, contents, tools)

        body            = response.body
        prompt_tokens   = body.dig("usageMetadata", "promptTokenCount")     || 0
        response_tokens = billed_output_tokens(body) || 0

        unless response.success?
          raise StandardError, body.to_json
        end

        parts         = body.dig("candidates", 0, "content", "parts") || []
        function_call = parts.find { |p| p["functionCall"] }
        text_part     = parts.find { |p| p["text"].present? }

        if function_call
          fn_name = function_call.dig("functionCall", "name")
          fn_args = function_call.dig("functionCall", "args") || {}

          progress_block&.call("#{fn_name.humanize} #{fn_args.values.first}...")

          # Search results and fetched pages are third-party text: neutralize injection first.
          tool_result = AiGatekeeper.scan_untrusted(execute_tool(fn_name, fn_args))
          trace << { tool: fn_name, args: fn_args, result: tool_result.truncate(500) }

          contents << {
            role:  "model",
            parts: [{ functionCall: { name: fn_name, args: fn_args } }]
          }
          contents << {
            role:  "user",
            parts: [{
              functionResponse: {
                name:     fn_name,
                response: { content: tool_result }
              }
            }]
          }
        elsif text_part
          return [text_part["text"], prompt_tokens, response_tokens]
        else
          raise GeminiError, "Unexpected empty response from Gemini agent."
        end
      end

      raise GeminiError, "Agent loop exceeded #{MAX_AGENT_ROUNDS} rounds without a final response."
    end
  end

  def call_gemini_with_tools(ai_template, contents, tools)
    http = Faraday.new do |conn|
      conn.request  :json
      conn.response :json
      conn.adapter  Faraday.default_adapter
    end

    http.post("#{BASE_URL}/models/#{ai_template.model}:generateContent") do |req|
      req.headers["x-goog-api-key"] = ENV.fetch("GEMINI_API_KEY")
      req.body = {
        contents:         contents,
        tools:            tools,
        generationConfig: {
          maxOutputTokens: ai_template.max_output_tokens,
          temperature:     ai_template.temperature.to_f
        }
      }
    end
  end

  def build_tool_definitions
    [{
      functionDeclarations: [
        {
          name:        "search_web",
          description: "Search the web for recent information about a company or person.",
          parameters:  {
            type:       "OBJECT",
            properties: { query: { type: "STRING", description: "The search query." } },
            required:   ["query"]
          }
        },
        {
          name:        "fetch_url",
          description: "Fetch and read the content of a URL.",
          parameters:  {
            type:       "OBJECT",
            properties: { url: { type: "STRING", description: "The URL to fetch." } },
            required:   ["url"]
          }
        }
      ]
    }]
  end

  def execute_tool(name, args)
    case name
    when "search_web" then PerplexityService.search(args["query"].to_s)
    when "fetch_url"  then FetchUrlService.fetch(args["url"].to_s)
    else "Unknown tool: #{name}"
    end
  end

  def call_gemini(ai_template, rendered_prompt)
    full_prompt = [ai_template.system_prompt.presence, rendered_prompt].compact.join("\n\n")

    http = Faraday.new do |conn|
      conn.request  :json
      conn.response :json
      conn.adapter  Faraday.default_adapter
    end

    response = Timeout.timeout(TIMEOUT_SECONDS) do
      http.post("#{BASE_URL}/models/#{ai_template.model}:generateContent") do |req|
        req.headers["x-goog-api-key"] = ENV.fetch("GEMINI_API_KEY")
        req.body = {
          contents: [{ parts: [{ text: full_prompt }] }],
          generationConfig: {
            maxOutputTokens: ai_template.max_output_tokens,
            temperature:     ai_template.temperature.to_f
          }
        }
      end
    end

    unless response.success?
      raise StandardError, response.body.to_json
    end

    body    = response.body
    text    = (body.dig("candidates", 0, "content", "parts") || [])
                .map { |p| p["text"].to_s }
                .join

    prompt_tokens   = body.dig("usageMetadata", "promptTokenCount")     || estimate_tokens(full_prompt)
    response_tokens = billed_output_tokens(body) || estimate_tokens(text)

    [text, prompt_tokens, response_tokens]
  end

  def estimate_tokens(text)
    (text.to_s.length / 4.0).ceil
  end

  # Gemini Developer API paid-tier prices, in cents per 1M tokens (ai.google.dev/gemini-api/docs/pricing,
  # checked 2026-10-10). Output includes thinking tokens. Prompts here stay under the 200k-token tier.
  PRICES_CENTS_PER_MILLION = {
    "gemini-2.5-flash" => { input: 30.0,  output: 250.0 },
    "gemini-2.5-pro"   => { input: 125.0, output: 1000.0 }
  }.freeze

  def estimate_cost(prompt_tokens, response_tokens, model)
    rate = PRICES_CENTS_PER_MILLION.fetch(model.to_s, PRICES_CENTS_PER_MILLION["gemini-2.5-flash"])
    ((prompt_tokens.to_i * rate[:input]) + (response_tokens.to_i * rate[:output])) / 1_000_000.0
  end

  # Gemini bills thinking tokens as output, but reports them apart from the visible answer.
  def billed_output_tokens(body)
    usage = body["usageMetadata"] || {}
    return nil unless usage["candidatesTokenCount"] || usage["thoughtsTokenCount"]
    usage["candidatesTokenCount"].to_i + usage["thoughtsTokenCount"].to_i
  end

  def elapsed_ms(start)
    ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round
  end
end
