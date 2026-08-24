Rails.application.routes.draw do
  get "up", to: "rails/health#show", as: :rails_health_check

  root "dashboard#index"
  get "app_info", to: "app_info#show", as: :app_info
  get 'dashboard/index', to: 'dashboard#index', as: :dashboard

  # user sign up
  get "sign_up", to: "users#new", as: :sign_up
  post "sign_up", to: "users#create"
  get 'confirmations/confirm_email/:confirmation_token', to: 'confirmations#confirm_email', as: :email_confirmation

  # user sign in
  get "login", to: "sessions#new", as: :login
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy", as: :logout

  resources :user_assets do
    resources :asset_contributions, only: [:create, :destroy]
    resources :asset_valuations, only: [:create, :destroy]
  end
  resources :user_liabilities

  # Budget / cashflow allocator
  get "budget", to: "budget#index", as: :budget
  resources :budget_items, only: [:create, :update, :destroy]

  # Up Bank budget sync: preview (network) then apply (params only)
  get "budget/up_import", to: "up_imports#new", as: :new_up_import
  post "budget/up_import", to: "up_imports#create", as: :up_import
  
  # AI Assistant routes
  get "ai_assistant", to: "ai_assistant#index", as: :ai_assistant
  post "ai_assistant/chat", to: "ai_assistant#chat", as: :ai_assistant_chat
  delete "ai_assistant/history", to: "ai_assistant#clear_history", as: :ai_assistant_history

  # FIRE runway — how long the money lasts
  get "runway", to: "runway#index", as: :runway

  # Debt payoff planner
  get "payoff_planner", to: "payoff_planner#index", as: :payoff_planner

  # Investment loan tax outcomes
  get "loan_tax", to: "loan_tax#index", as: :loan_tax

  # Investment Comparison
  get "investment_comparison", to: "investment_comparison#index", as: :investment_comparison
  post "investment_comparison/calculate", to: "investment_comparison#calculate", as: :investment_comparison_calculate
end
