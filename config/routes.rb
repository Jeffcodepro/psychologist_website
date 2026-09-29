Rails.application.routes.draw do
  get "up", to: "rails/health#show", as: :rails_health_check

  devise_for :users, skip: :all
  devise_scope :user do
    get "admin/access/:access_key", to: "admin/sessions#new", as: :new_user_session
    post "admin/access/:access_key", to: "admin/sessions#create", as: :user_session
    delete "admin/logout", to: "admin/sessions#destroy", as: :destroy_user_session
    get "admin/access/:access_key/password/new", to: "admin/passwords#new", as: :new_user_password
    post "admin/password", to: "admin/passwords#create", as: :user_password
    get "admin/password/edit", to: "admin/passwords#edit", as: :edit_user_password
    match "admin/password", to: "admin/passwords#update", via: [:patch, :put]
  end

  namespace :admin do
    root to: "dashboard#index"
    resources :articles, only: %i[index new create] do
      resource :card, only: %i[edit update], controller: 'article_cards'
    end

    resources :contact_requests, only: %i[index show destroy] do
      post :deliver, on: :member
    end
    resource :translation, only: :create
    resource :site_setting, only: %i[edit update]

    get "pages/:page_id/preview/frame",
        to: "page_previews#frame",
        as: :page_preview_frame

    resources :pages do
      resource :preview,
               only: :show,
               controller: "page_previews"

      resource :publication,
               only: :create,
               controller: "page_publications"

      resources :sections, except: :show do
        collection do
          patch :swap_positions
          patch :swap_fields
        end

        member do
          patch :clear_field
        end

        resources :section_items, except: :show
      end
    end
  end

  scope "(/s/:site_slug)" do
    root to: "pages#home"
    get "contato", to: "contacts#show", as: :contact
    resources :contact_requests, only: :create, path: "contato"
    get ":slug", to: "pages#show", as: :public_page, constraints: { slug: /[a-z0-9\-]+/ }
  end
end
