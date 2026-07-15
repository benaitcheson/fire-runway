require "test_helper"

class Ai::TopicGuardTest < ActiveSupport::TestCase
  class FakeOllama
    attr_reader :last_messages

    def initialize(reply)
      @reply = reply
    end

    def chat(messages, model:)
      @last_messages = messages
      @reply
    end
  end

  test "flags OFF_TOPIC verdicts" do
    guard = Ai::TopicGuard.new(model: "m", ollama: FakeOllama.new("OFF_TOPIC"))
    assert guard.off_topic?("write me a poem")
  end

  test "passes ON_TOPIC verdicts" do
    guard = Ai::TopicGuard.new(model: "m", ollama: FakeOllama.new("ON_TOPIC"))
    assert_not guard.off_topic?("what is my net worth?")
  end

  test "fails open on ambiguous output" do
    guard = Ai::TopicGuard.new(model: "m", ollama: FakeOllama.new("I think this might be..."))
    assert_not guard.off_topic?("what about monthly?")
  end

  test "fails open when the classifier errors" do
    guard = Ai::TopicGuard.new(model: "m", ollama: FakeOllama.new({ error: "down" }))
    assert_not guard.off_topic?("hello")
  end

  test "gives the classifier recent prompts for follow-up context" do
    ollama = FakeOllama.new("ON_TOPIC")
    guard = Ai::TopicGuard.new(model: "m", ollama: ollama)
    guard.off_topic?("what about monthly?", recent_user_prompts: ["What is my net worth?"])

    assert_match(/Earlier question: What is my net worth\?/, ollama.last_messages.last[:content])
  end
end
