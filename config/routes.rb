Rails.application.routes.draw do
  get "up", to: "rails/health#show", as: :rails_health_check

  root "home#welcome"
  get 'dashboard/index', to: 'dashboard#index', as: :dashboard

  # user sign up
  get "sign_up", to: "users#new", as: :sign_up
  post "sign_up", to: "users#create"
  get 'confirmations/confirm_email/:confirmation_token', to: 'confirmations#confirm_email', as: :email_confirmation

  # user sign in
  get "login", to: "sessions#new", as: :login
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy", as: :logout

  resources :user_assets
  resources :user_liabilities

  # Budget / cashflow allocator
  get "budget", to: "budget#index", as: :budget
  resources :budget_items, only: [:create, :update, :destroy]
  
  # AI Assistant routes
  get "ai_assistant", to: "ai_assistant#index", as: :ai_assistant
  post "ai_assistant/chat", to: "ai_assistant#chat", as: :ai_assistant_chat

  # Investment Comparison
  get "investment_comparison", to: "investment_comparison#index", as: :investment_comparison
  post "investment_comparison/calculate", to: "investment_comparison#calculate", as: :investment_comparison_calculate
end
