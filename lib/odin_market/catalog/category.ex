defmodule OdinMarket.Catalog.Category do
  use Ash.Resource,
    otp_app: :odin_market,
    domain: OdinMarket.Catalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "categories"
    repo OdinMarket.Repo
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:name, :slug, :parent_id]
      change {OdinMarket.Changes.SetSlug, from: :name}
    end
  end

  policies do
    bypass actor_attribute_equals(:role, :admin) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if always()
    end

    policy action(:create) do
      authorize_if actor_attribute_equals(:role, :admin)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :slug, :string do
      allow_nil? false
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :parent, __MODULE__ do
      allow_nil? true
      public? true
    end

    has_many :children, __MODULE__ do
      destination_attribute :parent_id
      public? true
    end
  end

  identities do
    identity :unique_slug, [:slug]
  end
end
