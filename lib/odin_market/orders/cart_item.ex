defmodule OdinMarket.Orders.CartItem do
  use Ash.Resource,
    otp_app: :odin_market,
    domain: OdinMarket.Orders,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "cart_items"
    repo OdinMarket.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :add do
      accept []
      argument :listing_id, :uuid, allow_nil?: false
      argument :qty, :integer, allow_nil?: true
      argument :notes, :string, allow_nil?: true
      upsert? true
      upsert_identity :unique_line
      upsert_fields [:qty, :notes]
      change OdinMarket.Orders.Changes.AddToCart
    end

    update :update_line do
      require_atomic? false
      accept []
      argument :qty, :integer, allow_nil?: true
      argument :notes, :string, allow_nil?: true
      change OdinMarket.Orders.Changes.UpdateCartLine
    end
  end

  policies do
    bypass actor_attribute_equals(:role, :admin) do
      authorize_if always()
    end

    policy action_type([:read, :update, :destroy]) do
      authorize_if expr(buyer_id == ^actor(:id))
    end

    policy action(:add) do
      authorize_if actor_present()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :qty, :integer do
      allow_nil? false
      public? true
      constraints min: 1
    end

    attribute :notes, :string, public?: true

    timestamps()
  end

  relationships do
    belongs_to :buyer, OdinMarket.Accounts.User do
      allow_nil? false
    end

    belongs_to :listing, OdinMarket.Catalog.Listing do
      allow_nil? false
      public? true
    end
  end

  identities do
    identity :unique_line, [:buyer_id, :listing_id]
  end
end
