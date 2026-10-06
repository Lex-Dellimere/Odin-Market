defmodule OdinMarket.Accounts.User do
  use Ash.Resource,
    otp_app: :odin_market,
    domain: OdinMarket.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAuthentication]

  authentication do
    add_ons do
      log_out_everywhere do
        apply_on_password_change? true
      end

      confirmation :confirm_new_user do
        monitor_fields [:email]
        confirm_on_create? true
        confirm_on_update? false
        require_interaction? true
        confirmed_at_field :confirmed_at
        auto_confirm_actions [:sign_in_with_magic_link, :reset_password_with_token]
        sender OdinMarket.Accounts.User.Senders.SendNewUserConfirmationEmail
      end
    end

    tokens do
      enabled? true
      token_resource OdinMarket.Accounts.Token
      signing_secret OdinMarket.Secrets
      store_all_tokens? true
      require_token_presence_for_authentication? true
    end

    strategies do
      password :password do
        identity_field :email
        hash_provider AshAuthentication.BcryptProvider

        resettable do
          sender OdinMarket.Accounts.User.Senders.SendPasswordResetEmail
          # these action names become the default in a later release
          password_reset_action_name :reset_password_with_token
          request_password_reset_action_name :request_password_reset_token
        end
      end

      remember_me :remember_me
    end
  end

  postgres do
    table "users"
    repo OdinMarket.Repo
  end

  actions do
    defaults [:read]

    read :get_by_subject do
      description "Get a user by the subject claim in a JWT"
      argument :subject, :string, allow_nil?: false
      get? true
      prepare AshAuthentication.Preparations.FilterBySubject
      prepare OdinMarket.Accounts.Preparations.RejectDeleted
    end

    update :change_password do
      require_atomic? false
      accept []
      argument :current_password, :string, sensitive?: true, allow_nil?: false

      argument :password, :string,
        sensitive?: true,
        allow_nil?: false,
        constraints: [min_length: 8]

      argument :password_confirmation, :string, sensitive?: true, allow_nil?: false

      validate confirm(:password, :password_confirmation)

      validate {AshAuthentication.Strategy.Password.PasswordValidation,
                strategy_name: :password, password_argument: :current_password}

      change {AshAuthentication.Strategy.Password.HashPasswordChange, strategy_name: :password}
    end

    read :sign_in_with_password do
      description "Attempt to sign in using a email and password."
      get? true

      argument :email, :ci_string do
        description "The email to use for retrieving the user."
        allow_nil? false
      end

      argument :password, :string do
        description "The password to check for the matching user."
        allow_nil? false
        sensitive? true
      end

      prepare AshAuthentication.Strategy.Password.SignInPreparation
      prepare OdinMarket.Accounts.Preparations.RejectDeleted

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
    end

    read :sign_in_with_token do
      # exchanges the short-lived sign-in token from the liveview for a session token
      description "Attempt to sign in using a short-lived sign in token."
      get? true

      argument :token, :string do
        description "The short-lived sign in token."
        allow_nil? false
        sensitive? true
      end

      prepare AshAuthentication.Strategy.Password.SignInWithTokenPreparation
      prepare OdinMarket.Accounts.Preparations.RejectDeleted

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
    end

    create :register_with_password do
      description "Register a new user with a email and password."

      argument :email, :ci_string do
        allow_nil? false
      end

      argument :password, :string do
        description "The proposed password for the user, in plain text."
        allow_nil? false
        constraints min_length: 8
        sensitive? true
      end

      argument :password_confirmation, :string do
        description "The proposed password for the user (again), in plain text."
        allow_nil? false
        sensitive? true
      end

      argument :username, :string do
        allow_nil? false
      end

      argument :display_name, :string do
        allow_nil? true
      end

      argument :policy_accepted, :boolean do
        allow_nil? false
      end

      accept []

      change set_attribute(:email, arg(:email))

      change OdinMarket.Accounts.Changes.PrepareRegistration

      change AshAuthentication.Strategy.Password.HashPasswordChange

      change AshAuthentication.GenerateTokenChange

      validate AshAuthentication.Strategy.Password.PasswordConfirmationValidation

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
    end

    action :request_password_reset_token do
      description "Send password reset instructions to a user if they exist."

      argument :email, :ci_string do
        allow_nil? false
      end

      run {AshAuthentication.Strategy.Password.RequestPasswordReset, action: :get_by_email}
    end

    read :get_by_email do
      description "Looks up a user by their email"
      get_by :email
    end

    update :reset_password_with_token do
      argument :reset_token, :string do
        allow_nil? false
        sensitive? true
      end

      argument :password, :string do
        description "The proposed password for the user, in plain text."
        allow_nil? false
        constraints min_length: 8
        sensitive? true
      end

      argument :password_confirmation, :string do
        description "The proposed password for the user (again), in plain text."
        allow_nil? false
        sensitive? true
      end

      validate AshAuthentication.Strategy.Password.ResetTokenValidation

      validate AshAuthentication.Strategy.Password.PasswordConfirmationValidation

      change AshAuthentication.Strategy.Password.HashPasswordChange

      change AshAuthentication.GenerateTokenChange
    end

    update :mark_confirmed do
      require_atomic? false
      accept []

      change fn changeset, _context ->
        now = DateTime.utc_now() |> DateTime.truncate(:microsecond)
        Ash.Changeset.force_change_attribute(changeset, :confirmed_at, now)
      end
    end

    update :set_role do
      require_atomic? false
      accept [:role]

      change fn changeset, context ->
        actor = context.actor
        user = changeset.data

        cond do
          actor && actor.id == user.id ->
            Ash.Changeset.add_error(changeset,
              field: :role,
              message: "Another admin has to change your role."
            )

          not is_nil(user.deleted_at) ->
            Ash.Changeset.add_error(changeset,
              field: :role,
              message: "This account is closed."
            )

          true ->
            changeset
        end
      end
    end

    update :set_selling do
      require_atomic? false
      accept [:selling]
    end

    update :store_customer do
      accept [:stripe_customer_id]
    end

    update :save_profile do
      require_atomic? false

      accept [
        :username,
        :display_name,
        :ship_name,
        :ship_line1,
        :ship_line2,
        :ship_city,
        :ship_region,
        :ship_postal_code,
        :ship_country
      ]

      change OdinMarket.Accounts.Changes.NormalizeProfile
    end

    update :delete_account do
      require_atomic? false
      accept []

      argument :current_password, :string do
        sensitive? true
        allow_nil? false
      end

      validate {AshAuthentication.Strategy.Password.PasswordValidation,
                strategy_name: :password, password_argument: :current_password}

      change OdinMarket.Accounts.Changes.DeleteAccount
    end

    update :revoke do
      require_atomic? false
      accept []

      argument :note, :string do
        allow_nil? true
      end

      change OdinMarket.Accounts.Changes.RevokeAccount
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    bypass action(:get_by_subject) do
      authorize_if always()
    end

    bypass actor_attribute_equals(:role, :admin) do
      authorize_if always()
    end

    policy action(:mark_confirmed) do
      authorize_if actor_attribute_equals(:role, :admin)
    end

    policy action(:set_role) do
      authorize_if actor_attribute_equals(:role, :admin)
    end

    policy action(:revoke) do
      authorize_if actor_attribute_equals(:role, :admin)
    end

    policy action(:set_selling) do
      forbid_unless actor_attribute_equals(:role, :admin)
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if expr(id == ^actor(:id))
    end

    policy action_type(:update) do
      authorize_if expr(id == ^actor(:id))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :ci_string do
      allow_nil? false
      public? true
    end

    attribute :hashed_password, :string do
      allow_nil? false
      sensitive? true
    end

    attribute :confirmed_at, :utc_datetime_usec

    attribute :username, :ci_string do
      allow_nil? false
      public? true
    end

    attribute :display_name, :string do
      allow_nil? false
      default "Member"
      public? true
    end

    attribute :role, :atom do
      allow_nil? false
      default :member
      public? true
      constraints one_of: [:member, :forum_moderator, :vendor_moderator, :admin]
    end

    attribute :policy_accepted_at, :utc_datetime_usec
    attribute :policy_version, :string

    attribute :selling, :boolean do
      allow_nil? false
      default false
      public? true
    end

    attribute :avatar_url, :string, public?: true
    attribute :stripe_customer_id, :string

    attribute :deleted_at, :utc_datetime_usec do
      public? true
    end

    attribute :ship_name, :string, public?: true
    attribute :ship_line1, :string, public?: true
    attribute :ship_line2, :string, public?: true
    attribute :ship_city, :string, public?: true
    attribute :ship_region, :string, public?: true
    attribute :ship_postal_code, :string, public?: true
    attribute :ship_country, :string, public?: true
  end

  relationships do
    has_one :vendor_profile, OdinMarket.Accounts.VendorProfile
  end

  identities do
    identity :unique_email, [:email]
    identity :unique_username, [:username]
  end
end
