class AiAssistantController < ApplicationController
  before_action :initialize_ollama

  def index
    @models = @ollama.list_models
  end

  def chat
    @prompt = params[:prompt]
    @model = params[:model] || ENV['OLLAMA_DEFAULT_MODEL']
    
    if @prompt.present?
      @response = @ollama.generate(@prompt, model: @model)
    else
      @response = { error: "Please provide a prompt" }
    end

    respond_to do |format|
      format.json { render json: { response: @response } }
      format.html { 
        @models = @ollama.list_models
        render :index 
      }
      format.turbo_stream {
        @models = @ollama.list_models
        render :index
      }
    end
  end

  private

  def initialize_ollama
    @ollama = OllamaService.new
  end
end