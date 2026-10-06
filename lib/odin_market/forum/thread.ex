defmodule OdinMarket.Forum.Thread do
  use Ash.Resource,
    otp_app: :odin_market,
    domain: OdinMarket.Forum,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "forum_threads"
    repo OdinMarket.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :open do
      accept [:title, :board_id]
      argument :body, :string, allow_nil?: false
      validate string_length(:title, min: 3, max: 140)
      validate string_length(:body, min: 1, max: 4000)
      change OdinMarket.Forum.Changes.OpenThread
    end
  end

  policies do
    bypass actor_attribute_equals(:role, :admin) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if always()
    end

    policy action(:open) do
      authorize_if actor_present()
    end

    policy action(:destroy) do
      authorize_if expr(author_id == ^actor(:id))
      authorize_if actor_attribute_equals(:role, :forum_moderator)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      allow_nil? false
      public? true
      constraints min_length: 3, max_length: 140
    end

    timestamps()
  end

  relationships do
    belongs_to :board, OdinMarket.Forum.Board do
      allow_nil? false
      public? true
    end

    belongs_to :author, OdinMarket.Accounts.User do
      allow_nil? true
      public? true
    end

    has_many :posts, OdinMarket.Forum.Post do
      sort inserted_at: :asc
      public? true
    end
  end
end
