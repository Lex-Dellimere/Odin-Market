defmodule OdinMarket.Catalog.Listing do
  use Ash.Resource,
    otp_app: :odin_market,
    domain: OdinMarket.Catalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "listings"
    repo OdinMarket.Repo
  end

  actions do
    defaults [:read]

    read :get_by_slug do
      argument :slug, :string, allow_nil?: false
      get? true

      filter expr(
               slug == ^arg(:slug) and status == :active and vendor.status == :active and
                 vendor.held == false
             )
    end

    read :search do
      pagination offset?: true, countable: true, default_limit: 12, required?: false

      argument :q, :string, allow_nil?: true
      argument :category_id, :string, allow_nil?: true
      argument :kind, :string, allow_nil?: true
      argument :vendor_id, :string, allow_nil?: true
      argument :min_price, :string, allow_nil?: true
      argument :max_price, :string, allow_nil?: true
      argument :in_stock, :string, allow_nil?: true
      argument :max_lead_days, :string, allow_nil?: true
      argument :sort, :string, allow_nil?: true

      prepare OdinMarket.Catalog.Preparations.SearchListings
    end

    create :publish do
      accept [
        :title,
        :description,
        :kind,
        :price_cents,
        :shipping_cents,
        :qty_available,
        :lead_days,
        :category_id
      ]

      argument :voltage, :string, allow_nil?: true
      argument :package, :string, allow_nil?: true
      argument :interface, :string, allow_nil?: true
      argument :mcu, :string, allow_nil?: true

      argument :status, :atom do
        allow_nil? true
        constraints one_of: [:draft, :active]
      end

      change OdinMarket.Catalog.Changes.PrepareListing
      change {OdinMarket.Changes.SetSlug, from: :title}
    end

    update :save do
      require_atomic? false

      accept [
        :title,
        :description,
        :kind,
        :price_cents,
        :shipping_cents,
        :qty_available,
        :lead_days,
        :category_id
      ]

      argument :voltage, :string, allow_nil?: true
      argument :package, :string, allow_nil?: true
      argument :interface, :string, allow_nil?: true
      argument :mcu, :string, allow_nil?: true

      argument :status, :atom do
        allow_nil? true
        constraints one_of: [:draft, :active]
      end

      change OdinMarket.Catalog.Changes.PrepareListing
    end

    update :set_stock do
      require_atomic? false
      accept [:qty_available]
      change OdinMarket.Catalog.Changes.SetStock
    end

    update :archive do
      accept []
      change set_attribute(:status, :archived)
    end

    update :mark_sold_out do
      accept []
      change set_attribute(:status, :sold_out)
    end

    # callers only run this when qty_available still covers the qty
    update :decrement_stock do
      accept []
      argument :qty, :integer, allow_nil?: false
      change atomic_update(:qty_available, expr(qty_available - ^arg(:qty)))
    end
  end

  policies do
    bypass actor_attribute_equals(:role, :admin) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if expr(status == :active and vendor.status == :active and vendor.held == false)
      authorize_if expr(vendor.user_id == ^actor(:id))
    end

    policy action(:publish) do
      authorize_if actor_attribute_equals(:selling, true)
    end

    policy action([:save, :archive, :set_stock]) do
      forbid_unless actor_attribute_equals(:selling, true)
      authorize_if expr(vendor.user_id == ^actor(:id))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      allow_nil? false
      public? true
      constraints max_length: 140
    end

    attribute :slug, :string do
      allow_nil? false
      public? true
    end

    attribute :description, :string do
      public? true
      constraints max_length: 5000
    end

    attribute :kind, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:stock, :custom]
    end

    attribute :price_cents, :integer do
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

    attribute :qty_available, :integer, public?: true
    attribute :lead_days, :integer, public?: true

    attribute :specs, :map do
      allow_nil? false
      default %{}
      public? true
    end

    attribute :status, :atom do
      allow_nil? false
      default :draft
      public? true
      constraints one_of: [:draft, :active, :sold_out, :archived]
    end

    timestamps()
  end

  relationships do
    belongs_to :vendor, OdinMarket.Accounts.VendorProfile do
      allow_nil? false
    end

    belongs_to :category, OdinMarket.Catalog.Category do
      allow_nil? false
      public? true
    end

    has_many :images, OdinMarket.Catalog.ListingImage do
      sort position: :asc
      public? true
    end
  end

  identities do
    identity :unique_slug, [:slug]
  end
end
