Rails.application.routes.draw do
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

  # user assets crud
  resources :user_assets
end
