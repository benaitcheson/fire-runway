class AiAssistantController < ApplicationController
  before_action :initialize_ollama

  def index
    @models = @ollama.list_models
  end

  def chat
    @prompt = params[:prompt]
    @model = params[:model] || ENV['OLLAMA_DEFAULT_MODEL']
    
    begin
      if @prompt.present?
        # Build financial context for the AI
        financial_context = build_financial_context
        enhanced_prompt = build_enhanced_prompt(@prompt, financial_context)
        
        @response = @ollama.generate(enhanced_prompt, model: @model)
      else
        @response = { error: "Please provide a prompt" }
      end
    rescue => e
      Rails.logger.error "Chat error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      @response = { error: "An error occurred: #{e.message}" }
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
  
  def build_financial_context
    return { summary: {}, assets: [], liabilities: [] } unless current_user
    
    assets = current_user.user_assets.includes(:user)
    liabilities = current_user.user_liabilities.includes(:user)
    
    # Calculate totals
    total_asset_purchase_value = assets.sum(:purchase_price_cents)
    total_asset_current_value = assets.sum(&:current_value_cents)
    total_liabilities = liabilities.sum(:amount_cents)
    net_worth = total_asset_current_value - total_liabilities
    total_depreciation = total_asset_purchase_value - total_asset_current_value
    
    # Build context hash
    {
      summary: {
        total_assets_purchase_value: format_currency_for_ai(total_asset_purchase_value),
        total_assets_current_value: format_currency_for_ai(total_asset_current_value),
        total_liabilities: format_currency_for_ai(total_liabilities),
        net_worth: format_currency_for_ai(net_worth),
        total_depreciation: format_currency_for_ai(total_depreciation),
        number_of_assets: assets.count,
        number_of_liabilities: liabilities.count
      },
      assets: assets.map do |asset|
        {
          name: asset.item_name,
          purchase_price: format_currency_for_ai(asset.purchase_price_cents),
          current_value: format_currency_for_ai(asset.current_value_cents),
          purchase_date: asset.purchase_date&.strftime("%B %Y"),
          depreciation_method: asset.depreciation_method,
          depreciation_percentage: asset.depreciation_percentage,
          useful_life_years: asset.useful_life_years,
          age_in_years: asset.calculate_years_owned.round(1)
        }
      end,
      liabilities: liabilities.map do |liability|
        {
          name: liability.item_name,
          amount: format_currency_for_ai(liability.amount_cents),
          currency: liability.amount_currency,
          date_added: liability.created_at&.strftime("%B %Y")
        }
      end
    }
  end
  
  def build_enhanced_prompt(user_prompt, financial_context)
    context_text = build_context_text(financial_context)
    
    <<~PROMPT
      You are a helpful financial assistant. The user has provided their complete financial information below. Use this context to provide personalized, accurate financial advice.

      FINANCIAL CONTEXT:
      #{context_text}

      USER'S QUESTION:
      #{user_prompt}

      Please provide a helpful response based on the financial information provided. Be specific and reference their actual assets, liabilities, and net worth when relevant. Format currency amounts clearly and provide practical, actionable advice.
    PROMPT
  end
  
  def build_context_text(context)
    summary = context[:summary]
    assets = context[:assets]
    liabilities = context[:liabilities]
    
    text = []
    
    # Summary section
    text << "FINANCIAL SUMMARY:"
    text << "- Net Worth: #{summary[:net_worth]}"
    text << "- Total Assets (Current Value): #{summary[:total_assets_current_value]}"
    text << "- Total Assets (Purchase Value): #{summary[:total_assets_purchase_value]}"
    text << "- Total Liabilities: #{summary[:total_liabilities]}"
    text << "- Total Depreciation: #{summary[:total_depreciation]}"
    text << "- Number of Assets: #{summary[:number_of_assets]}"
    text << "- Number of Liabilities: #{summary[:number_of_liabilities]}"
    text << ""
    
    # Assets section
    if assets.any?
      text << "ASSETS:"
      assets.each do |asset|
        depreciation_info = if asset[:depreciation_method] != 'none'
          " (#{asset[:depreciation_percentage]}% depreciated over #{asset[:age_in_years]} years using #{asset[:depreciation_method]} method)"
        else
          ""
        end
        
        text << "- #{asset[:name]}: #{asset[:current_value]} current value (purchased for #{asset[:purchase_price]} in #{asset[:purchase_date]})#{depreciation_info}"
      end
      text << ""
    end
    
    # Liabilities section
    if liabilities.any?
      text << "LIABILITIES:"
      liabilities.each do |liability|
        text << "- #{liability[:name]}: #{liability[:amount]} (added #{liability[:date_added]})"
      end
      text << ""
    end
    
    text.join("\n")
  end
  
  def format_currency_for_ai(cents, currency = "AUD")
    return "$0.00" if cents.nil? || cents == 0
    
    # Convert cents to dollars
    amount = cents / 100.0
    
    # Format with appropriate currency symbol for AI readability
    formatted_amount = sprintf("%.2f", amount).reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    
    case currency
    when "AUD"
      "$#{formatted_amount}"
    when "USD"
      "US$#{formatted_amount}"
    else
      "#{currency} #{formatted_amount}"
    end
  end
end