defmodule OdinMarket.Accounts.VendorProfile do
  use Ash.Resource,
    otp_app: :odin_market,
    domain: OdinMarket.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "vendor_profiles"
    repo OdinMarket.Repo
  end

  actions do
    defaults [:read]

    read :by_slug do
      argument :slug, :string, allow_nil?: false
      get? true
      filter expr(slug == ^arg(:slug) and status == :active and held == false)
    end

    create :create do
      accept [:shop_name, :bio, :location, :website, :user_id]
      change {OdinMarket.Changes.SetSlug, from: :shop_name}
      change set_attribute(:status, :active)
      change OdinMarket.Accounts.Changes.NormalizeWebsite
    end

    update :update_shop do
      require_atomic? false
      accept [:shop_name, :bio, :location, :website]
      change OdinMarket.Accounts.Changes.NormalizeWebsite
    end

    update :set_status do
      accept [:status]
    end

    update :sync_subscription do
      require_atomic? false

      accept [
        :status,
        :subscription_status,
        :stripe_subscription_id,
        :stripe_price_id,
        :current_period_end
      ]
    end

    update :set_hold do
      require_atomic? false
      accept [:held]
    end
  end

  policies do
    bypass actor_attribute_equals(:role, :admin) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if expr(status == :active and held == false)
      authorize_if expr(user_id == ^actor(:id))
    end

    policy action(:update_shop) do
      authorize_if expr(user_id == ^actor(:id))
    end

    policy action(:create) do
      authorize_if actor_attribute_equals(:role, :admin)
    end

    policy action(:set_status) do
      authorize_if actor_attribute_equals(:role, :admin)
    end

    policy action(:set_hold) do
      authorize_if actor_attribute_equals(:role, :admin)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :shop_name, :string do
      allow_nil? false
      public? true
    end

    attribute :slug, :string do
      allow_nil? false
      public? true
    end

    attribute :bio, :string, public?: true
    attribute :location, :string, public?: true
    attribute :website, :string, public?: true

    attribute :status, :atom do
      allow_nil? false
      default :active
      public? true
      constraints one_of: [:pending, :active, :suspended]
    end

    attribute :stripe_account_id, :string, public?: true
    attribute :stripe_subscription_id, :string
    attribute :stripe_price_id, :string

    attribute :subscription_status, :atom do
      allow_nil? false
      default :none
      public? true
      constraints one_of: [:none, :active, :past_due, :canceled]
    end

    attribute :current_period_end, :utc_datetime_usec, public?: true

    attribute :held, :boolean do
      allow_nil? false
      default false
    end

    timestamps()
  end

  relationships do
    belongs_to :user, OdinMarket.Accounts.User do
      allow_nil? false
    end
  end

  identities do
    identity :unique_slug, [:slug]
    identity :unique_user, [:user_id]
  end
end
