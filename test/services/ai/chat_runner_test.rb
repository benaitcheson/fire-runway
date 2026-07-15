require "test_helper"

class Ai::ChatRunnerTest < ActiveSupport::TestCase
  # Fake Ollama that returns scripted messages and records what it was sent.
  class FakeOllama
    attr_reader :calls

    def initialize(*messages)
      @script = messages
      @calls = []
    end

    def chat_with_tools(messages:, tools:, model:)
      @calls << messages.dup
      @script.shift
    end
  end

  # Guard stub that always answers the same way.
  class FakeGuard
    def initialize(off_topic) = @off_topic = off_topic
    def off_topic?(*) = @off_topic
  end

  setup { @user = users(:one) }

  def call_runner(ollama, prompt: "hi", off_topic: false)
    Ai::ChatRunner.new(user: @user, prompt: prompt, model: "m",
                       ollama: ollama, topic_guard: FakeGuard.new(off_topic)).call
  end

  test "returns content directly when the model uses no tools" do
    ollama = FakeOllama.new({ "content" => "Hello!" })
    result = call_runner(ollama, prompt: "hi")
    assert_equal "Hello!", result[:content]
  end

  test "dispatches tool calls and feeds results back to the model" do
    ollama = FakeOllama.new(
      { "content" => "", "role" => "assistant",
        "tool_calls" => [{ "function" => { "name" => "get_net_worth_summary", "arguments" => {} } }] },
      { "content" => "Your net worth is $1,500." }
    )
    result = call_runner(ollama, prompt: "net worth?")

    assert_equal "Your net worth is $1,500.", result[:content]
    tool_message = ollama.calls.last.find { |m| m[:role] == "tool" }
    assert_match(/net_worth/, tool_message[:content])
  end

  test "unknown tool names come back as contained errors, not exceptions" do
    ollama = FakeOllama.new(
      { "content" => "", "tool_calls" => [{ "function" => { "name" => "delete_everything", "arguments" => {} } }] },
      { "content" => "done" }
    )
    result = call_runner(ollama, prompt: "x")

    assert_equal "done", result[:content]
    tool_message = ollama.calls.last.find { |m| m[:role] == "tool" }
    assert_match(/Unknown tool/, tool_message[:content])
  end

  test "gives up after the turn cap" do
    looping = Array.new(10) do
      { "content" => "", "tool_calls" => [{ "function" => { "name" => "list_assets", "arguments" => {} } }] }
    end
    ollama = FakeOllama.new(*looping)
    result = call_runner(ollama, prompt: "x")

    assert_match(/too many steps/, result[:error])
    assert_equal Ai::ChatRunner::MAX_TURNS, ollama.calls.size
  end

  test "propagates ollama errors" do
    ollama = FakeOllama.new({ error: "connection refused" })
    result = call_runner(ollama, prompt: "x")
    assert_equal "connection refused", result[:error]
  end

  test "persists the exchange after a successful answer" do
    ollama = FakeOllama.new({ "content" => "You own a laptop." })
    assert_difference("@user.ai_messages.count", 2) do
      call_runner(ollama, prompt: "what do I own?")
    end

    assert_equal %w[user assistant], @user.ai_messages.chronological.last(2).map(&:role)
    assert_equal "You own a laptop.", @user.ai_messages.chronological.last.content
  end

  test "does not persist when the model errors" do
    ollama = FakeOllama.new({ error: "boom" })
    assert_no_difference("AiMessage.count") { call_runner(ollama, prompt: "x") }
  end

  test "includes saved history in the context sent to the model" do
    @user.ai_messages.create!(role: "user", content: "What is my net worth?")
    @user.ai_messages.create!(role: "assistant", content: "It is $1,500.")

    ollama = FakeOllama.new({ "content" => "About $125/month." })
    call_runner(ollama, prompt: "and monthly?")

    sent = ollama.calls.first
    assert_equal "system", sent.first[:role]
    assert_includes sent.map { |m| m[:content] }, "What is my net worth?"
    assert_includes sent.map { |m| m[:content] }, "It is $1,500."
    assert_equal "and monthly?", sent.last[:content]
  end

  test "does not include another user's history" do
    users(:two).ai_messages.create!(role: "user", content: "SECRET question")

    ollama = FakeOllama.new({ "content" => "ok" })
    call_runner(ollama, prompt: "hi")

    assert ollama.calls.first.none? { |m| m[:content].to_s.include?("SECRET") }
  end

  test "off-topic prompts are refused before any model call" do
    ollama = FakeOllama.new
    result = call_runner(ollama, prompt: "write me a poem about pirates", off_topic: true)

    assert_equal Ai::TopicGuard::REFUSAL, result[:content]
    assert_empty ollama.calls, "tool loop must not run for off-topic prompts"
    assert_equal Ai::TopicGuard::REFUSAL, @user.ai_messages.chronological.last.content
  end
end
