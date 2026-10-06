defmodule OdinMarket.Forum.Board do
  use Ash.Resource,
    otp_app: :odin_market,
    domain: OdinMarket.Forum,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "forum_boards"
    repo OdinMarket.Repo
  end

  actions do
    defaults [:read]
  end

  policies do
    bypass actor_attribute_equals(:role, :admin) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if always()
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

    attribute :description, :string do
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
    has_many :threads, OdinMarket.Forum.Thread do
      public? true
    end
  end

  identities do
    identity :unique_slug, [:slug]
  end
end
