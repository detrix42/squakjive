Rails.application.routes.draw do

  # dashboard for when user is logged in
  get :dashboard, to: "dashboard#index"
  resources :circles, param: :circle_id do
    member do
      get :add_user_modal
      post :add_user, param: :user_id
    end

  end

  delete "/circle_memberships", to: "circle_memberships#destroy"

  devise_for :users
  get "main/home"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"

  root to: "main#home"

  resources :squaks, only: [:create]
end
