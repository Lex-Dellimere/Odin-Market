defmodule OdinMarket.Forum.Post do
  use Ash.Resource,
    otp_app: :odin_market,
    domain: OdinMarket.Forum,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "forum_posts"
    repo OdinMarket.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :reply do
      accept [:thread_id, :body]
      validate string_length(:body, min: 1, max: 4000)

      change fn changeset, context ->
        Ash.Changeset.force_change_attribute(changeset, :author_id, context.actor.id)
      end
    end

    create :create_opening do
      accept [:thread_id, :body, :author_id, :opening]
    end

    update :edit do
      require_atomic? false
      accept [:body]
      validate string_length(:body, min: 1, max: 4000)
    end
  end

  policies do
    bypass actor_attribute_equals(:role, :admin) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if always()
    end

    policy action(:reply) do
      authorize_if actor_present()
    end

    policy action(:create_opening) do
      authorize_if actor_attribute_equals(:role, :admin)
    end

    policy action(:edit) do
      authorize_if expr(author_id == ^actor(:id))
    end

    policy action(:destroy) do
      authorize_if expr(author_id == ^actor(:id))
      authorize_if actor_attribute_equals(:role, :forum_moderator)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :body, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 4000
    end

    attribute :opening, :boolean do
      allow_nil? false
      default false
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :thread, OdinMarket.Forum.Thread do
      allow_nil? false
      public? true
    end

    belongs_to :author, OdinMarket.Accounts.User do
      allow_nil? true
      public? true
    end
  end
end
