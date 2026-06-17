Rails.application.routes.draw do
  mount ActiveStorage::Engine => "/rails/active_storage"

  get "attachments/create"
  get "attachments/:signed_id/view", to: "attachments#view", as: :attachment_view

  get "link_preview/show"

  # get "link_preview", to: "link_preview#show"

  get "user_profile/selected_circle"

  # dashboard for when user is logged in
  get :dashboard, to: "dashboard#index"

  patch 'user_profile/update_selected_circle', to: 'user_profile#update_selected_circle'

  get 'squaks/:circle_id', to: 'squaks#squaks'

  resources :circles, param: :circle_id do
    member do
      get :add_user_modal
      get :squaks
      post :add_user, param: :user_id
      post :invite_user
    end
  end

  resources :user_invites, only: [:destroy] do
    post :accept, on: :member
    delete :decline, on: :member
  end

  delete "/circle_memberships", to: "circle_memberships#destroy"
  delete "/circle_memberships/self", to: "circle_memberships#destroy_self"

  devise_for :users
  get "main/home"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  resources :squaks, only: [:create, :destroy]
  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  # resources :attachments, only: [:create]
  # # Handles GET /rails/active_storage/blobs/:sgid/preview
  get "/rails/active_storage/blobs/:sgid/preview",
      to: "active_storage/blobs#preview",
      as: :blob_preview
  post "/rails/active_storage/blobs/:sgid/analyze",
       to: "active_storage/blobs#analyze",
       as: :blob_analyze
  # Defines the root path route ("/")
  # root "posts#index"

  # Ensure ActiveStorage routes are accessible
  direct :rails_storage_disk do
    get "/rails/active_storage/disk/:encoded_key/*filename", to: "active_storage/disk#show", as: :rails_disk_service
  end

  namespace :api do
    namespace :v1 do
      get "uploads/create"
      resource :metadata, only: [:show]
      resources :uploads, only: [:create]
    end
  end

  root to: "main#home"


end
