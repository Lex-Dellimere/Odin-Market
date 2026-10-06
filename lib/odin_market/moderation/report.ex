defmodule OdinMarket.Moderation.Report do
  use Ash.Resource,
    otp_app: :odin_market,
    domain: OdinMarket.Moderation,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "reports"
    repo OdinMarket.Repo
  end

  actions do
    defaults [:read]

    create :file do
      accept [:target_type, :target_id, :reason, :note]
      change OdinMarket.Moderation.Changes.FileReport
    end

    update :dismiss do
      require_atomic? false
      accept [:resolution_note]

      change {OdinMarket.Moderation.Changes.ResolveReport, status: :dismissed}
    end

    update :close do
      require_atomic? false
      accept []
      change {OdinMarket.Moderation.Changes.ResolveReport, status: :actioned}
    end
  end

  policies do
    policy action(:file) do
      authorize_if actor_present()
    end

    policy action_type(:read) do
      access_type :strict
      authorize_if actor_attribute_equals(:role, :admin)
      authorize_if actor_attribute_equals(:role, :forum_moderator)
      authorize_if actor_attribute_equals(:role, :vendor_moderator)
    end

    policy action_type(:read) do
      authorize_if actor_attribute_equals(:role, :admin)

      authorize_if expr(
                     ^actor(:role) == :forum_moderator and
                       target_type in [:forum_post, :forum_thread]
                   )

      authorize_if expr(
                     ^actor(:role) == :vendor_moderator and
                       target_type in [:message, :listing, :user]
                   )
    end

    policy action([:dismiss, :close]) do
      access_type :strict
      authorize_if actor_attribute_equals(:role, :admin)
      authorize_if actor_attribute_equals(:role, :forum_moderator)
      authorize_if actor_attribute_equals(:role, :vendor_moderator)
    end

    policy action([:dismiss, :close]) do
      authorize_if actor_attribute_equals(:role, :admin)

      authorize_if expr(
                     ^actor(:role) == :forum_moderator and
                       target_type in [:forum_post, :forum_thread]
                   )

      authorize_if expr(
                     ^actor(:role) == :vendor_moderator and
                       target_type in [:message, :listing, :user]
                   )
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :target_type, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:forum_post, :forum_thread, :message, :listing, :user]
    end

    attribute :target_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :reason, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:spam, :harassment, :scam, :off_topic, :other]
    end

    attribute :note, :string do
      public? true
      constraints max_length: 500
    end

    attribute :excerpt, :string do
      constraints max_length: 280
    end

    attribute :reporter_name, :string do
      allow_nil? false
      public? true
    end

    attribute :subject_name, :string do
      public? true
    end

    attribute :status, :atom do
      allow_nil? false
      default :open
      public? true
      constraints one_of: [:open, :dismissed, :actioned]
    end

    attribute :resolution_note, :string do
      constraints max_length: 500
    end

    attribute :handled_at, :utc_datetime_usec

    timestamps()
  end

  relationships do
    belongs_to :reporter, OdinMarket.Accounts.User do
      allow_nil? false
    end

    belongs_to :subject, OdinMarket.Accounts.User do
      allow_nil? true
    end

    belongs_to :handler, OdinMarket.Accounts.User do
      allow_nil? true
    end
  end
end
