defmodule OdinMarket.Accounts do
  use Ash.Domain, otp_app: :odin_market, extensions: [AshAdmin.Domain]

  require Ash.Query

  admin do
    show? true
  end

  resources do
    resource OdinMarket.Accounts.Token

    resource OdinMarket.Accounts.User do
      define :get_user_by_id, action: :read, get_by: :id, get?: true
    end

    resource OdinMarket.Accounts.VendorProfile do
      define :get_shop_by_slug, action: :by_slug, args: [:slug], get?: true
    end

    resource OdinMarket.Accounts.PaymentCard
  end

  def save_profile(actor, params) do
    Ash.update(actor, params, action: :save_profile, actor: actor)
  end

  def profile_for(%{id: user_id}) do
    OdinMarket.Accounts.VendorProfile
    |> Ash.Query.filter(user_id == ^user_id)
    |> Ash.read_one!(authorize?: false)
  end

  def profile_for(_), do: nil

  def fresh_user(%{id: id}) do
    case Ash.get(OdinMarket.Accounts.User, id, authorize?: false) do
      {:ok, user} -> user
      _ -> nil
    end
  end

  def fresh_user(_), do: nil

  def vendor?(%{selling: true} = user) do
    case profile_for(user) do
      %{status: :active, held: held} when held != true -> true
      _ -> false
    end
  end

  def vendor?(_), do: false

  def grant_vendor(user, attrs \\ %{})

  def grant_vendor(%{deleted_at: deleted_at}, _attrs) when not is_nil(deleted_at) do
    {:error, :revoked}
  end

  def grant_vendor(user, attrs) do
    profile =
      case profile_for(user) do
        nil ->
          {:ok, created} =
            Ash.create(
              OdinMarket.Accounts.VendorProfile,
              %{shop_name: shop_name(user, attrs), user_id: user.id},
              action: :create,
              authorize?: false
            )

          created

        profile ->
          profile
      end

    sync =
      %{status: :active, subscription_status: attrs[:subscription_status] || :active}
      |> put_present(:stripe_subscription_id, attrs[:stripe_subscription_id])
      |> put_present(:stripe_price_id, attrs[:stripe_price_id])
      |> put_present(:current_period_end, attrs[:current_period_end])

    {:ok, _} =
      Ash.update(profile, sync, action: :sync_subscription, authorize?: false)

    Ash.update(user, %{selling: true}, action: :set_selling, authorize?: false)
  end

  def pause_vendor(user, attrs \\ %{}) do
    case profile_for(user) do
      nil ->
        :ok

      profile ->
        Ash.update(
          profile,
          %{
            status: :suspended,
            subscription_status: attrs[:subscription_status] || :canceled
          },
          action: :sync_subscription,
          authorize?: false
        )
    end

    Ash.update(user, %{selling: false}, action: :set_selling, authorize?: false)
  end

  defp shop_name(user, attrs) do
    cond do
      is_binary(attrs[:shop_name]) and String.trim(attrs[:shop_name]) != "" ->
        String.trim(attrs[:shop_name])

      is_binary(user.display_name) and user.display_name != "" ->
        user.display_name

      true ->
        to_string(user.username)
    end
  end

  defp put_present(map, _key, nil), do: map
  defp put_present(map, key, value), do: Map.put(map, key, value)

  def list_cards(user) do
    OdinMarket.Accounts.PaymentCard
    |> Ash.Query.filter(user_id == ^user.id)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.read!(actor: user)
  end

  def save_card(user, attrs) do
    Ash.create(OdinMarket.Accounts.PaymentCard, attrs, action: :save, actor: user)
  end

  def remove_card(card, actor) do
    case OdinMarket.Payments.detach_card(card) do
      :ok -> Ash.destroy(card, actor: actor)
      {:error, reason} -> {:error, reason}
    end
  end
end
