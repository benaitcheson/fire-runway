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

  setup { @user = users(:one) }

  test "returns content directly when the model uses no tools" do
    ollama = FakeOllama.new({ "content" => "Hello!" })
    result = Ai::ChatRunner.new(user: @user, prompt: "hi", model: "m", ollama: ollama).call
    assert_equal "Hello!", result[:content]
  end

  test "dispatches tool calls and feeds results back to the model" do
    ollama = FakeOllama.new(
      { "content" => "", "role" => "assistant",
        "tool_calls" => [{ "function" => { "name" => "get_net_worth_summary", "arguments" => {} } }] },
      { "content" => "Your net worth is $1,500." }
    )
    result = Ai::ChatRunner.new(user: @user, prompt: "net worth?", model: "m", ollama: ollama).call

    assert_equal "Your net worth is $1,500.", result[:content]
    tool_message = ollama.calls.last.find { |m| m[:role] == "tool" }
    assert_match(/net_worth/, tool_message[:content])
  end

  test "unknown tool names come back as contained errors, not exceptions" do
    ollama = FakeOllama.new(
      { "content" => "", "tool_calls" => [{ "function" => { "name" => "delete_everything", "arguments" => {} } }] },
      { "content" => "done" }
    )
    result = Ai::ChatRunner.new(user: @user, prompt: "x", model: "m", ollama: ollama).call

    assert_equal "done", result[:content]
    tool_message = ollama.calls.last.find { |m| m[:role] == "tool" }
    assert_match(/Unknown tool/, tool_message[:content])
  end

  test "gives up after the turn cap" do
    looping = Array.new(10) do
      { "content" => "", "tool_calls" => [{ "function" => { "name" => "list_assets", "arguments" => {} } }] }
    end
    ollama = FakeOllama.new(*looping)
    result = Ai::ChatRunner.new(user: @user, prompt: "x", model: "m", ollama: ollama).call

    assert_match(/too many steps/, result[:error])
    assert_equal Ai::ChatRunner::MAX_TURNS, ollama.calls.size
  end

  test "propagates ollama errors" do
    ollama = FakeOllama.new({ error: "connection refused" })
    result = Ai::ChatRunner.new(user: @user, prompt: "x", model: "m", ollama: ollama).call
    assert_equal "connection refused", result[:error]
  end
end
