require 'ollama-ai'

class OllamaService
  attr_reader :client

  def initialize
    @client = Ollama.new(
      credentials: { address: 'http://localhost:11434' },
      options: { server_sent_events: true }
    )
  end

  def generate(prompt, model: 'llama3.2:latest')
    response = @client.generate(
      { model: model, prompt: prompt }
    )
    
    extract_response(response)
  rescue => e
    Rails.logger.error "Ollama generation error: #{e.message}"
    { error: e.message }
  end

  def chat(messages, model: 'llama3.2:latest')
    response = @client.chat(
      { model: model, messages: messages }
    )
    
    extract_response(response)
  rescue => e
    Rails.logger.error "Ollama chat error: #{e.message}"
    { error: e.message }
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

  def extract_response(response)
    if response.is_a?(Array)
      response.map { |r| r['response'] }.join('')
    else
      response['response'] || response['message']['content']
    end
  end
end