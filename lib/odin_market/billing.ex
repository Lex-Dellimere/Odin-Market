defmodule OdinMarket.Billing do
  @moduledoc false

  require Ash.Query

  alias OdinMarket.Accounts
  alias OdinMarket.Accounts.User
  alias OdinMarket.Accounts.VendorProfile

  @plans [
    %{id: "month", name: "Monthly", amount: "A$25", detail: "Billed every month", cents: 2500},
    %{
      id: "quarter",
      name: "3 months",
      amount: "A$70",
      detail: "Billed every 3 months",
      cents: 7000
    },
    %{id: "year", name: "Yearly", amount: "A$240", detail: "Billed every year", cents: 24000}
  ]

  def plans, do: @plans

  def checkout(user, plan_id) do
    with price when is_binary(price) and price != "" <- price_id(plan_id),
         key when is_binary(key) <- api_key(),
         {:ok, user} <- OdinMarket.Payments.ensure_customer(user) do
      params = %{
        mode: "subscription",
        customer: user.stripe_customer_id,
        client_reference_id: user.id,
        success_url: success_url(),
        cancel_url: "#{OdinMarketWeb.Endpoint.url()}/vendor/pricing",
        metadata: %{user_id: user.id, kind: "vendor"},
        subscription_data: %{metadata: %{user_id: user.id}},
        line_items: [%{price: price, quantity: 1}]
      }

      case Stripe.Checkout.Session.create(params, api_key: key) do
        {:ok, session} -> {:ok, session.url}
        {:error, error} -> {:error, error}
      end
    else
      _ -> {:error, :subscription_unconfigured}
    end
  end

  def portal(user) do
    with key when is_binary(key) <- api_key(),
         {:ok, user} <- OdinMarket.Payments.ensure_customer(user) do
      params = %{
        customer: user.stripe_customer_id,
        return_url: "#{OdinMarketWeb.Endpoint.url()}/dashboard/billing"
      }

      case Stripe.BillingPortal.Session.create(params, api_key: key) do
        {:ok, session} -> {:ok, session.url}
        {:error, error} -> {:error, error}
      end
    else
      _ -> {:error, :subscription_unconfigured}
    end
  end

  def apply_checkout(session) do
    with {:ok, %User{} = user} <- find_user(session) do
      grant(user, %{
        stripe_subscription_id: subscription_ref(session),
        subscription_status: :active
      })
    else
      _ -> :ok
    end
  end

  def apply_event("customer.subscription.updated", object), do: sync_subscription(object)
  def apply_event("customer.subscription.deleted", object), do: pause(object, :canceled)
  def apply_event("invoice.paid", object), do: grant_invoice(object)
  def apply_event("invoice.payment_failed", object), do: pause(object, :past_due)
  def apply_event(_type, _object), do: :ok

  defp sync_subscription(object) do
    case find_user(object) do
      {:ok, %User{} = user} ->
        status = text(object, :status)

        attrs = %{
          stripe_subscription_id: subscription_ref(object),
          stripe_price_id: price_from(object),
          current_period_end: period_end(object),
          subscription_status: stored_status(status)
        }

        if status in ["active", "trialing"] do
          grant(user, attrs)
        else
          pause_user(user, attrs.subscription_status)
        end

      _ ->
        :ok
    end
  end

  defp grant_invoice(object) do
    case find_user(object) do
      {:ok, %User{} = user} ->
        grant(user, %{
          stripe_subscription_id: subscription_ref(object),
          subscription_status: :active
        })

      _ ->
        :ok
    end
  end

  defp pause(object, status) when is_map(object) do
    case find_user(object) do
      {:ok, %User{} = user} -> pause_user(user, status)
      _ -> :ok
    end
  end

  defp grant(%{deleted_at: deleted_at}, _attrs) when not is_nil(deleted_at), do: :ok

  defp grant(user, attrs) do
    case Accounts.grant_vendor(user, attrs) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp pause_user(user, status) do
    case Accounts.pause_vendor(user, %{subscription_status: status}) do
      {:ok, _} -> :ok
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp find_user(object) do
    cond do
      id = meta_user(object) -> Ash.get(User, id, authorize?: false)
      id = uuid(text(object, :client_reference_id)) -> Ash.get(User, id, authorize?: false)
      sub = subscription_ref(object) -> user_from_subscription(sub)
      customer = text(object, :customer) -> user_from_customer(customer)
      true -> {:ok, nil}
    end
  end

  defp user_from_subscription(sub_id) do
    case VendorProfile
         |> Ash.Query.filter(stripe_subscription_id == ^sub_id)
         |> Ash.read_one(authorize?: false) do
      {:ok, %{user_id: user_id}} -> Ash.get(User, user_id, authorize?: false)
      _ -> {:ok, nil}
    end
  end

  defp user_from_customer(customer_id) do
    User
    |> Ash.Query.filter(stripe_customer_id == ^customer_id)
    |> Ash.read_one(authorize?: false)
  end

  defp meta_user(object) when is_map(object) do
    meta = Map.get(object, :metadata) || Map.get(object, "metadata") || %{}
    uuid(Map.get(meta, :user_id) || Map.get(meta, "user_id"))
  end

  defp meta_user(_), do: nil

  defp uuid(value) do
    case Ecto.UUID.cast(to_string(value || "")) do
      {:ok, id} -> id
      _ -> nil
    end
  end

  defp subscription_ref(object) do
    id = text(object, :id)
    nested = text(object, :subscription)

    cond do
      is_binary(id) and String.starts_with?(id, "sub_") -> id
      is_binary(nested) -> nested
      true -> nil
    end
  end

  defp price_from(object) do
    items =
      case object do
        %{items: %{data: data}} when is_list(data) -> data
        %{"items" => %{"data" => data}} when is_list(data) -> data
        _ -> []
      end

    case List.first(items) do
      nil -> nil
      item -> text(item, :price)
    end
  end

  defp period_end(object) do
    unix =
      Map.get(object, :current_period_end) ||
        Map.get(object, "current_period_end") ||
        item_period(object)

    cond do
      is_integer(unix) ->
        unix |> DateTime.from_unix!() |> DateTime.truncate(:microsecond)

      is_binary(unix) ->
        case Integer.parse(unix) do
          {n, _} -> n |> DateTime.from_unix!() |> DateTime.truncate(:microsecond)
          _ -> nil
        end

      true ->
        nil
    end
  end

  defp item_period(object) do
    items =
      case object do
        %{items: %{data: data}} when is_list(data) -> data
        %{"items" => %{"data" => data}} when is_list(data) -> data
        _ -> []
      end

    case List.first(items) do
      nil -> nil
      item -> Map.get(item, :current_period_end) || Map.get(item, "current_period_end")
    end
  end

  defp text(object, key) when is_map(object) do
    value = Map.get(object, key) || Map.get(object, Atom.to_string(key))

    cond do
      is_binary(value) and value != "" -> value
      is_map(value) and is_binary(Map.get(value, :id)) -> Map.get(value, :id)
      is_map(value) and is_binary(Map.get(value, "id")) -> Map.get(value, "id")
      true -> nil
    end
  end

  defp text(_, _), do: nil

  defp stored_status(status) when status in ["active", "trialing"], do: :active
  defp stored_status(status) when status in ["past_due", "unpaid"], do: :past_due
  defp stored_status(status) when status in ["canceled", "incomplete_expired"], do: :canceled
  defp stored_status(_), do: :none

  defp success_url do
    "#{OdinMarketWeb.Endpoint.url()}/dashboard/billing?session_id={CHECKOUT_SESSION_ID}"
  end

  defp price_id("month"), do: System.get_env("STRIPE_PRICE_VENDOR_MONTH")
  defp price_id("quarter"), do: System.get_env("STRIPE_PRICE_VENDOR_QUARTER")
  defp price_id("year"), do: System.get_env("STRIPE_PRICE_VENDOR_YEAR")
  defp price_id(_), do: nil

  defp api_key do
    value = Application.get_env(:stripity_stripe, :api_key)
    if is_binary(value) and value != "", do: value
  end
end
