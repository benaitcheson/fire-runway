class AiAssistantController < ApplicationController
  before_action :initialize_ollama

  def index
    @models = @ollama.list_models
    @messages = current_user.ai_messages.chronological.last(20)
  end

  def clear_history
    current_user.ai_messages.destroy_all
    redirect_to ai_assistant_path, notice: "Conversation cleared."
  end

  def chat
    @prompt = params[:prompt]
    @model = params[:model] || ENV["OLLAMA_DEFAULT_MODEL"] || "llama3.2:latest"

    @response =
      if @prompt.present?
        result = Ai::ChatRunner.new(user: current_user, prompt: @prompt, model: @model).call
        result[:error] ? { error: result[:error] } : result[:content]
      else
        { error: "Please provide a prompt" }
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
