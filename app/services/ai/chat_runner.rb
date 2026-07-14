# Runs one user prompt through the tool-calling loop:
# system prompt + question -> model -> (tool calls -> results -> model)* -> answer.
# The model only ever sees tool results, never the database.
module Ai
  class ChatRunner
    MAX_TURNS = 6

    def initialize(user:, prompt:, model:, ollama: OllamaService.new)
      @user = user
      @prompt = prompt
      @model = model
      @ollama = ollama
      @executor = ToolExecutor.new(user: user)
    end

    def call
      messages = [
        { role: "system", content: Prompts.system_prompt },
        { role: "user", content: @prompt }
      ]

      MAX_TURNS.times do
        message = @ollama.chat_with_tools(messages: messages, tools: Tools::ALL, model: @model)
        return { error: message[:error] } if message.is_a?(Hash) && message[:error]

        tool_calls = message["tool_calls"]
        return { content: message["content"].to_s } if tool_calls.blank?

        messages << message
        tool_calls.each do |call|
          name = call.dig("function", "name").to_s
          args = call.dig("function", "arguments") || {}
          messages << { role: "tool", content: @executor.execute(name, args) }
        end
      end

      { error: "The assistant used too many steps without reaching an answer." }
    end
  end
end
