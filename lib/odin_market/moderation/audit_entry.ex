defmodule OdinMarket.Moderation.AuditEntry do
  use Ash.Resource,
    otp_app: :odin_market,
    domain: OdinMarket.Moderation,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "moderation_audits"
    repo OdinMarket.Repo
  end

  actions do
    defaults [:read]

    create :record do
      accept [:actor_id, :action, :target_type, :target_id, :note]
    end
  end

  policies do
    policy action(:record) do
      authorize_if actor_attribute_equals(:role, :admin)
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
                       target_type in [:message, :listing, :vendor_profile]
                   )
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :action, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :delete_post,
                    :delete_thread,
                    :delete_message,
                    :archive_listing,
                    :hold_shop,
                    :release_shop,
                    :dismiss_report,
                    :revoke_account,
                    :set_role
                  ]
    end

    attribute :target_type, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :forum_post,
                    :forum_thread,
                    :message,
                    :listing,
                    :vendor_profile,
                    :user
                  ]
    end

    attribute :target_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :note, :string do
      constraints max_length: 500
    end

    timestamps()
  end

  relationships do
    belongs_to :actor, OdinMarket.Accounts.User do
      allow_nil? false
    end
  end
end
