module Evals
  module Adapters
    # Runs the outreach research agent the same way LeadsController#generate_outreach
    # does (GeminiService.generate_with_tools: search_web via Perplexity, fetch_url),
    # synchronously and without saving a Lead or OutreachEmail. Each tool call becomes
    # a trace entry for the A (max_tool_calls) and F (tools_subset_of, called_tool) checks.
    class CollectivecrmAgent
      def initialize(template_name)
        @template_name = template_name
      end

      def call(variables:, user:)
        result = GeminiService.generate_with_tools(template: @template_name, variables: variables, user: user)
        Result.new(output: result[:raw], trace: result[:trace].map { |step| { tool: step[:tool], args: step[:args] } })
      end
    end
  end
end
