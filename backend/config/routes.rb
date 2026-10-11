Rails.application.routes.draw do
  post   "/signup",     to: "users#create"
  post   "/login",      to: "sessions#create"
  post   "/auth/token", to: "sessions#refresh"
  delete "/logout",     to: "sessions#destroy"
  get    "/me",         to: "users#me"

  resources :projects, only: %i[index show create destroy] do
    member do
      post :start
      post :stop
    end
    resources :runs, only: :index
  end

  resources :runs, only: :show do
    resources :logs,     only: :index
    resources :commands, only: %i[index create]
  end

  mount ActionCable.server => "/cable"
end
