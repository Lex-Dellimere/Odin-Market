defmodule OdinMarket.Chat.Conversation do
  use Ash.Resource,
    otp_app: :odin_market,
    domain: OdinMarket.Chat,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "conversations"
    repo OdinMarket.Repo
  end

  actions do
    defaults [:read]

    create :open do
      accept []
      argument :listing_id, :uuid, allow_nil?: false
      change OdinMarket.Chat.Changes.OpenConversation
    end

    update :touch do
      accept []
      change atomic_update(:updated_at, expr(now()))
    end
  end

  policies do
    bypass actor_attribute_equals(:role, :admin) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if expr(buyer_id == ^actor(:id))
      authorize_if expr(vendor.user_id == ^actor(:id))
    end

    policy action(:open) do
      authorize_if actor_present()
    end
  end

  attributes do
    uuid_primary_key :id
    timestamps()
  end

  relationships do
    belongs_to :buyer, OdinMarket.Accounts.User do
      allow_nil? false
    end

    belongs_to :vendor, OdinMarket.Accounts.VendorProfile do
      allow_nil? false
    end

    belongs_to :listing, OdinMarket.Catalog.Listing do
      allow_nil? false
      public? true
    end

    has_many :messages, OdinMarket.Chat.Message do
      sort inserted_at: :asc
      public? true
    end
  end

  identities do
    identity :unique_thread, [:buyer_id, :vendor_id, :listing_id]
  end
end
