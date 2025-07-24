Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "healthcheckz" => "rails/health#show", as: :rails_health_check

  namespace :api, defaults: { format: 'json' } do
    resources :users, only: %i[show destroy]
  end

  resources :sessions, only: %i[index new]
  resource :passwordless, only: %i[create show], controller: :passwordless do
    get "callback", on: :member
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
