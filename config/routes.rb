Rails.application.routes.draw do
  root "home#welcome"

  # user sign up
  get "sign_up", to: "users#new", as: :sign_up
  post "sign_up", to: "users#create"
  get 'confirmations/confirm_email/:confirmation_token', to: 'confirmations#confirm_email', as: :email_confirmation
end
