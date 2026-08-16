# Ollama configuration
# Make sure Ollama is running locally on http://localhost:11434
# You can start it with: ollama serve

# Optional: Set default model
ENV['OLLAMA_DEFAULT_MODEL'] ||= 'qwen3:8b'

# Verify Ollama is available on boot (in development only)
if Rails.env.development?
  begin
    require 'net/http'
    uri = URI('http://localhost:11434/api/tags')
    response = Net::HTTP.get_response(uri)
    
    if response.code == '200'
      Rails.logger.info "✓ Ollama is running at http://localhost:11434"
    else
      Rails.logger.warn "⚠️  Ollama server returned status #{response.code}"
    end
  rescue => e
    Rails.logger.warn "⚠️  Ollama is not running. Start it with: ollama serve"
    Rails.logger.warn "   Error: #{e.message}"
  end
end