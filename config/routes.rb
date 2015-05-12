Spree::Core::Engine.add_routes do
  namespace :admin do
    resources :addresses do
      collection do
        put '/update_addresses', to: 'addresses#update_addresses', as: :update_addresses
      end
    end
    resources :users
  end

  resources :addresses
end
