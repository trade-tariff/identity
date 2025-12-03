Rails.application.routes.draw do
  get "/healthcheck", to: "healthcheck#check"
  get "/healthcheckz", to: "healthcheck#checkz"

  namespace :api, defaults: { format: 'json' } do
    resources :users, only: %i[show destroy]
  end

  resources :sessions, only: %i[index new]
  resource :passwordless, only: %i[create show], controller: :passwordless do
    get "callback", on: :member
    get "invalid", on: :member
  end

  get "login", to: "sessions#new"

  TradeTariffIdentity::CONSUMERS&.each do |consumer|
    consumer_id = consumer[:id]
    get consumer_id, to: "sessions#index", defaults: { consumer_id: }
  end

  match "/400", to: "errors#bad_request", via: :all
  match "/404", to: "errors#not_found", via: :all
  match "/500", to: "errors#internal_server_error", via: :all

  root to: "sessions#index"
end
