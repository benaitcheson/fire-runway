require 'ollama-ai'

class OllamaService
  # Ollama loads qwen3 with a 4k context unless told otherwise, which tool
  # results and reference excerpts overflow. Every chat call sends the same
  # value: a call with a different num_ctx makes Ollama reload the model.
  CONTEXT_LENGTH = ENV.fetch('OLLAMA_NUM_CTX', 12_288).to_i

  attr_reader :client

  def initialize
    @client = Ollama.new(
      credentials: { address: ENV.fetch('OLLAMA_URL', 'http://localhost:11434') },
      options: { server_sent_events: true }
    )
  end

  def generate(prompt, model: ENV.fetch('OLLAMA_DEFAULT_MODEL', 'qwen3:8b'))
    response = @client.generate(
      { model: model, prompt: prompt, options: model_options }
    )
    
    extract_response(response)
  rescue => e
    Rails.logger.error "Ollama generation error: #{e.message}"
    { error: e.message }
  end

  def chat(messages, model: ENV.fetch('OLLAMA_DEFAULT_MODEL', 'qwen3:8b'))
    response = @client.chat(
      { model: model, messages: messages, options: model_options }
    )

    extract_response(response)
  rescue => e
    Rails.logger.error "Ollama chat error: #{e.message}"
    { error: e.message }
  end

  # Tool-calling chat. Returns the raw assistant message hash (with "content"
  # and optionally "tool_calls") rather than flattened text.
  def chat_with_tools(messages:, tools:, model: ENV.fetch('OLLAMA_DEFAULT_MODEL', 'qwen3:8b'))
    response = json_client.chat(
      { model: model, messages: messages, tools: tools, stream: false, options: model_options }
    )

    payload = response.is_a?(Array) ? response.first : response
    payload&.dig('message') || { error: "Unexpected Ollama response: #{payload.inspect}" }
  rescue => e
    Rails.logger.error "Ollama tool chat error: #{e.message}"
    { error: e.message }
  end

  # One embedding per text from /api/embed (the endpoint the reference index
  # was built with). Raises on failure; callers decide how to report it.
  def embed(texts, model: ENV.fetch('OLLAMA_EMBED_MODEL', 'nomic-embed-text'))
    response = json_client.request('api/embed', { model: model, input: Array(texts) })
    payload = response.is_a?(Array) ? response.first : response
    payload.fetch('embeddings')
  end

  def list_models
    response = @client.tags
    # The ollama-ai gem returns an array with the response
    if response.is_a?(Array) && response.first
      response.first
    else
      response
    end
  rescue => e
    Rails.logger.error "Ollama list models error: #{e.message}"
    { error: e.message }
  end

  private

  def model_options
    { num_ctx: CONTEXT_LENGTH }
  end

  def json_client
    @json_client ||= Ollama.new(
      credentials: { address: ENV.fetch('OLLAMA_URL', 'http://localhost:11434') },
      options: { server_sent_events: false }
    )
  end

  def extract_response(response)
    Rails.logger.info "Ollama response: #{response.inspect}"
    
    if response.is_a?(Array)
      response.map { |r| r['response'] || r.dig('message', 'content') }.join('')
    elsif response.is_a?(Hash)
      response['response'] || response.dig('message', 'content') || response
    else
      response.to_s
    end
  end
end
