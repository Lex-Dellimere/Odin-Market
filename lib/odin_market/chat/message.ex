defmodule OdinMarket.Chat.Message do
  use Ash.Resource,
    otp_app: :odin_market,
    domain: OdinMarket.Chat,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "messages"
    repo OdinMarket.Repo
  end

  actions do
    defaults [:read]

    destroy :remove do
      primary? false
    end

    create :send do
      accept [:conversation_id, :body]

      change OdinMarket.Chat.Changes.SendMessage

      validate string_length(:body, min: 1, max: 2000)
    end

    update :mark_read do
      accept []
      change atomic_update(:read_at, expr(now()))
    end
  end

  policies do
    bypass actor_attribute_equals(:role, :admin) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if expr(conversation.buyer_id == ^actor(:id))
      authorize_if expr(conversation.vendor.user_id == ^actor(:id))
    end

    policy action(:send) do
      authorize_if actor_present()
    end

    policy action(:remove) do
      authorize_if actor_attribute_equals(:role, :admin)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :body, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 2000
    end

    attribute :read_at, :utc_datetime_usec

    timestamps()
  end

  relationships do
    belongs_to :conversation, OdinMarket.Chat.Conversation do
      allow_nil? false
      public? true
    end

    belongs_to :sender, OdinMarket.Accounts.User do
      allow_nil? false
    end
  end
end
