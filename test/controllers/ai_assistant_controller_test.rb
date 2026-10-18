require "test_helper"

class AiAssistantControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
  end

  test "page names no AI vendor and has a spinner for pending answers" do
    with_models({}) { get ai_assistant_url }
    assert_response :success
    assert_no_match(/ollama/i, response.body)
    assert_select "[data-ai-chat-target=status][role=status] svg.animate-spin"
    assert_select "[data-ai-chat-target=elapsed]"
  end

  private

  # The page lists installed models on load; stub the service so the test
  # never touches the network.
  def with_models(models)
    fake = Object.new.tap { |o| o.define_singleton_method(:list_models) { models } }
    OllamaService.singleton_class.alias_method(:original_new, :new)
    OllamaService.define_singleton_method(:new) { |*| fake }
    yield
  ensure
    OllamaService.singleton_class.alias_method(:new, :original_new)
    OllamaService.singleton_class.remove_method(:original_new)
  end
end
