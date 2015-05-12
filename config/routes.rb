Spree::Core::Engine.add_routes do
  namespace :admin do
    resources :addresses do
      collection do
        put '/update_addresses', to: 'addresses#update_addresses', as: :update_addresses
        get '/redirect_back', to: 'addresses#redirect_back', as: :redirect_back
      end
    end
    resources :users
  end

  resources :addresses
end
