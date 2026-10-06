defmodule OdinMarket.Accounts.Changes.RevokeAccount do
  @moduledoc false
  use Ash.Resource.Change

  require Ash.Query

  alias OdinMarket.Accounts.Token
  alias OdinMarket.Catalog.Listing
  alias OdinMarket.Orders.CartItem

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      user = changeset.data
      actor = context.actor

      cond do
        actor && actor.id == user.id ->
          error(changeset, "You cannot revoke your own account.")

        user.role == :admin ->
          error(changeset, "Demote an admin before revoking that account.")

        not is_nil(user.deleted_at) ->
          error(changeset, "This account is already closed.")

        true ->
          case teardown(user) do
            :ok -> anonymize(changeset, user)
            {:error, message} -> error(changeset, message)
          end
      end
    end)
  end

  defp teardown(user) do
    with :ok <- close_shop(user),
         :ok <- clear_cart(user),
         :ok <- clear_cards(user),
         :ok <- clear_tokens(user) do
      :ok
    end
  end

  defp close_shop(user) do
    case OdinMarket.Accounts.profile_for(user) do
      nil ->
        :ok

      profile ->
        # no proration and no final invoice, so the current period is not refunded
        cancel_subscription(profile.stripe_subscription_id)

        with :ok <- archive_listings(profile),
             {:ok, _} <-
               Ash.update(
                 profile,
                 %{
                   status: :suspended,
                   subscription_status: :canceled,
                   stripe_subscription_id: nil,
                   stripe_price_id: nil,
                   current_period_end: nil
                 },
                 action: :sync_subscription,
                 authorize?: false
               ),
             {:ok, _} <-
               Ash.update(profile, %{held: true}, action: :set_hold, authorize?: false) do
          :ok
        else
          _ -> {:error, "Could not close the shop."}
        end
    end
  end

  defp cancel_subscription(id) when is_binary(id) and id != "" do
    case present(Application.get_env(:stripity_stripe, :api_key)) do
      nil ->
        :ok

      key ->
        try do
          Stripe.Subscription.cancel(id, %{prorate: false, invoice_now: false}, api_key: key)
          :ok
        rescue
          _ -> :ok
        end
    end
  end

  defp cancel_subscription(_), do: :ok

  defp present(value) when is_binary(value) and value != "", do: value
  defp present(_), do: nil

  defp archive_listings(profile) do
    Listing
    |> Ash.Query.filter(vendor_id == ^profile.id and status != :archived)
    |> Ash.bulk_update(:archive, %{},
      strategy: [:atomic],
      authorize?: false,
      authorize_query?: false,
      return_errors?: true
    )
    |> bulk_ok("Could not archive listings.")
  end

  defp clear_cart(user) do
    CartItem
    |> Ash.Query.filter(buyer_id == ^user.id)
    |> Ash.bulk_destroy(:destroy, %{},
      strategy: [:stream],
      authorize?: false,
      authorize_query?: false,
      return_errors?: true
    )
    |> bulk_ok("Could not clear the cart.")
  end

  defp clear_cards(user) do
    user
    |> OdinMarket.Accounts.list_cards()
    |> Enum.reduce_while(:ok, fn card, :ok ->
      case OdinMarket.Accounts.remove_card(card, user) do
        :ok -> {:cont, :ok}
        {:ok, _} -> {:cont, :ok}
        {:error, _} -> {:halt, {:error, "Could not remove a saved card."}}
      end
    end)
  end

  defp clear_tokens(user) do
    subject = AshAuthentication.user_to_subject(user)

    Token
    |> Ash.Query.filter(subject == ^subject)
    |> Ash.bulk_destroy(:destroy, %{},
      strategy: [:stream],
      authorize?: false,
      authorize_query?: false,
      return_errors?: true
    )
    |> bulk_ok("Could not sign this account out.")
  end

  defp anonymize(changeset, user) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)
    {:ok, email} = Ash.Type.cast_input(Ash.Type.CiString, "deleted-#{user.id}@users.odin.market")
    password = Base.encode64(:crypto.strong_rand_bytes(32))
    {:ok, username} = Ash.Type.cast_input(Ash.Type.CiString, deleted_username(user))

    changeset
    |> Ash.Changeset.force_change_attribute(:email, email)
    |> Ash.Changeset.force_change_attribute(:username, username)
    |> Ash.Changeset.force_change_attribute(:display_name, "Deleted account")
    |> Ash.Changeset.force_change_attribute(:selling, false)
    |> Ash.Changeset.force_change_attribute(:role, :member)
    |> Ash.Changeset.force_change_attribute(:ship_name, nil)
    |> Ash.Changeset.force_change_attribute(:ship_line1, nil)
    |> Ash.Changeset.force_change_attribute(:ship_line2, nil)
    |> Ash.Changeset.force_change_attribute(:ship_city, nil)
    |> Ash.Changeset.force_change_attribute(:ship_region, nil)
    |> Ash.Changeset.force_change_attribute(:ship_postal_code, nil)
    |> Ash.Changeset.force_change_attribute(:ship_country, nil)
    |> Ash.Changeset.force_change_attribute(:stripe_customer_id, nil)
    |> Ash.Changeset.force_change_attribute(:avatar_url, nil)
    |> Ash.Changeset.force_change_attribute(:deleted_at, now)
    |> Ash.Changeset.force_change_attribute(:hashed_password, Bcrypt.hash_pwd_salt(password))
  end

  defp deleted_username(user) do
    fragment = user.id |> to_string() |> String.replace("-", "") |> String.slice(0, 12)
    "deleted_" <> fragment
  end

  defp bulk_ok(%Ash.BulkResult{status: :success}, _message), do: :ok
  defp bulk_ok(_result, message), do: {:error, message}

  defp error(changeset, message) do
    Ash.Changeset.add_error(changeset, field: :note, message: message)
  end
end
