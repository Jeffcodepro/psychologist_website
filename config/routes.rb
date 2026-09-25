Rails.application.routes.draw do
  devise_for :users

  devise_scope :user do
    get "admin/login",
        to: "devise/sessions#new",
        as: :admin_login

    delete "admin/logout",
           to: "devise/sessions#destroy",
           as: :admin_logout
  end

  root to: "pages#home"
  resources :contact_requests, only: :create, path: "contato"

  namespace :admin do
    root to: "dashboard#index"

    resources :contact_requests, only: %i[index show destroy]
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

  get "/:slug",
      to: "pages#show",
      as: :public_page,
      constraints: {
        slug: /[a-z0-9\-]+/
      }
end
