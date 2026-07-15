# Runs one user prompt through the tool-calling loop:
# guard -> system prompt + saved history + question -> model
#   -> (tool calls -> results -> model)* -> answer -> persist exchange.
# The model only ever sees tool results, never the database.
module Ai
  class ChatRunner
    MAX_TURNS = 6
    HISTORY_LIMIT = 10

    def initialize(user:, prompt:, model:, ollama: OllamaService.new, topic_guard: nil)
      @user = user
      @prompt = prompt
      @model = model
      @ollama = ollama
      @executor = ToolExecutor.new(user: user)
      @topic_guard = topic_guard || TopicGuard.new(model: model, ollama: ollama)
    end

    def call
      history = @user.ai_messages.recent_context(limit: HISTORY_LIMIT)

      if off_topic?(history)
        persist_exchange!(TopicGuard::REFUSAL)
        return { content: TopicGuard::REFUSAL }
      end

      messages = [{ role: "system", content: Prompts.system_prompt }] + history +
                 [{ role: "user", content: @prompt }]

      MAX_TURNS.times do
        message = @ollama.chat_with_tools(messages: messages, tools: Tools::ALL, model: @model)
        return { error: message[:error] } if message.is_a?(Hash) && message[:error]

        tool_calls = message["tool_calls"]
        if tool_calls.blank?
          content = message["content"].to_s
          persist_exchange!(content)
          return { content: content }
        end

        messages << message
        tool_calls.each do |call|
          name = call.dig("function", "name").to_s
          args = call.dig("function", "arguments") || {}
          messages << { role: "tool", content: @executor.execute(name, args) }
        end
      end

      { error: "The assistant used too many steps without reaching an answer." }
    end

    private

    def off_topic?(history)
      recent_user_prompts = history.select { |m| m[:role] == "user" }.map { |m| m[:content] }
      @topic_guard.off_topic?(@prompt, recent_user_prompts: recent_user_prompts)
    end

    def persist_exchange!(answer)
      @user.ai_messages.create!(role: "user", content: @prompt)
      @user.ai_messages.create!(role: "assistant", content: answer)
    end
  end
end
