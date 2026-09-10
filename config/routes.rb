Rails.application.routes.draw do
  devise_for :users

  # API JSON consumida por el SPA
  namespace :api do
    namespace :v1 do
      resources :users, only: %i[index show update]
      resources :backlog_items, only: %i[index create update]
      resources :sprints, only: %i[index show create update] do
        resources :daily_snapshots, only: %i[create]
      end
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # SPA
  root "home#index"
end
