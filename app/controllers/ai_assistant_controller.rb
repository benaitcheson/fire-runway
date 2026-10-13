class AiAssistantController < ApplicationController
  before_action :initialize_ollama
  before_action :load_profile, only: [:index, :chat]

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
    @model = params[:model] || ENV.fetch("OLLAMA_DEFAULT_MODEL", "qwen3:8b")

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

  # The page nudges the user to finish their fact-finder profile.
  def load_profile
    @profile = current_user.profile
  end
end
