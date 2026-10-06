defmodule OdinMarket.Catalog.ListingImage do
  use Ash.Resource,
    otp_app: :odin_market,
    domain: OdinMarket.Catalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "listing_images"
    repo OdinMarket.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:listing_id, :url, :position]
      change OdinMarket.Catalog.Changes.OwnListingImage
    end
  end

  policies do
    bypass actor_attribute_equals(:role, :admin) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if always()
    end

    policy action([:create, :destroy]) do
      authorize_if actor_present()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :url, :string do
      allow_nil? false
      public? true
    end

    attribute :position, :integer do
      allow_nil? false
      default 0
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :listing, OdinMarket.Catalog.Listing do
      allow_nil? false
      public? true
    end
  end
end
