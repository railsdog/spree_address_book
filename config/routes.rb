Spree::Core::Engine.add_routes do
  namespace :admin do
    resources :orders do
      resources :addresses
    end
    resources :users do
      get 'addresses/:address_id/edit', to: 'users#edit_address', as: :edit_address
      put 'addresses/:address_id/edit', to: 'users#edit_address', as: :edit_address_put
    end
  end

  resources :addresses
end
