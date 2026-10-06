defmodule OdinMarket.Accounts.PaymentCard do
  use Ash.Resource,
    otp_app: :odin_market,
    domain: OdinMarket.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "payment_cards"
    repo OdinMarket.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :save do
      accept [:stripe_payment_method_id, :brand, :last4, :exp_month, :exp_year]
      upsert? true
      upsert_identity :unique_method
      upsert_fields [:brand, :last4, :exp_month, :exp_year]

      change fn changeset, context ->
        case context.actor do
          %{id: user_id} ->
            Ash.Changeset.force_change_attribute(changeset, :user_id, user_id)

          _ ->
            Ash.Changeset.add_error(changeset, field: :user_id, message: "unauthenticated")
        end
      end
    end
  end

  policies do
    bypass actor_attribute_equals(:role, :admin) do
      authorize_if always()
    end

    policy action_type([:read, :destroy]) do
      authorize_if expr(user_id == ^actor(:id))
    end

    policy action(:save) do
      authorize_if actor_present()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :stripe_payment_method_id, :string do
      allow_nil? false
      public? true
    end

    attribute :brand, :string do
      allow_nil? false
      public? true
    end

    attribute :last4, :string do
      allow_nil? false
      public? true
      constraints min_length: 4, max_length: 4
    end

    attribute :exp_month, :integer, public?: true
    attribute :exp_year, :integer, public?: true

    timestamps()
  end

  relationships do
    belongs_to :user, OdinMarket.Accounts.User do
      allow_nil? false
    end
  end

  identities do
    identity :unique_method, [:stripe_payment_method_id]
  end
end
