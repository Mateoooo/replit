Rails.application.routes.draw do
  post   "/signup", to: "users#create"
  post   "/login",  to: "sessions#create"
  delete "/logout", to: "sessions#destroy"
  get    "/me",     to: "users#me"
end