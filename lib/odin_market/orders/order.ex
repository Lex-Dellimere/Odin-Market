defmodule OdinMarket.Orders.Order do
  use Ash.Resource,
    otp_app: :odin_market,
    domain: OdinMarket.Orders,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "orders"
    repo OdinMarket.Repo
  end

  actions do
    defaults [:read]

    create :open do
      accept []
      argument :listing_id, :uuid, allow_nil?: false
      argument :qty, :integer, allow_nil?: false
      argument :notes, :string, allow_nil?: true
      change OdinMarket.Orders.Changes.OpenOrder
    end

    update :revise do
      require_atomic? false
      accept []
      argument :qty, :integer, allow_nil?: false
      argument :notes, :string, allow_nil?: true
      change OdinMarket.Orders.Changes.ReviseOrder
    end

    update :store_session do
      accept [:stripe_checkout_session_id]
    end

    update :mark_paid do
      accept []
      validate attribute_equals(:status, :pending_payment)
      change set_attribute(:status, :paid)
    end

    # a second webhook matches zero rows because callers filter pending_payment
    update :claim_paid do
      accept []
      change set_attribute(:status, :paid)
    end

    update :cancel_oversold do
      accept [:note]
      validate attribute_equals(:status, :pending_payment)
      change set_attribute(:status, :cancelled)
    end

    # runs after a paid claim when stock can no longer be decremented
    update :cancel_claimed do
      accept [:note]
      change set_attribute(:status, :cancelled)
    end

    update :advance do
      require_atomic? false
      accept []

      argument :status, :atom do
        allow_nil? false
        constraints one_of: [:in_progress, :shipped, :complete]
      end

      change OdinMarket.Orders.Changes.AdvanceStatus
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

    policy action(:revise) do
      authorize_if expr(buyer_id == ^actor(:id))
    end

    policy action(:advance) do
      authorize_if expr(vendor.user_id == ^actor(:id))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :qty, :integer do
      allow_nil? false
      public? true
      constraints min: 1
    end

    attribute :unit_price_cents, :integer do
      allow_nil? false
      public? true
      constraints min: 1
    end

    attribute :shipping_cents, :integer do
      allow_nil? false
      default 0
      public? true
      constraints min: 0
    end

    attribute :currency, :string do
      allow_nil? false
      default "aud"
      public? true
    end

    attribute :status, :atom do
      allow_nil? false
      default :pending_payment
      public? true

      constraints one_of: [
                    :pending_payment,
                    :paid,
                    :in_progress,
                    :shipped,
                    :complete,
                    :refunded,
                    :cancelled
                  ]
    end

    attribute :notes, :string, public?: true
    attribute :note, :string, public?: true
    attribute :stripe_checkout_session_id, :string

    attribute :ship_name, :string, public?: true
    attribute :ship_line1, :string, public?: true
    attribute :ship_line2, :string, public?: true
    attribute :ship_city, :string, public?: true
    attribute :ship_region, :string, public?: true
    attribute :ship_postal_code, :string, public?: true
    attribute :ship_country, :string, public?: true

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
  end
end
