defmodule OdinMarket.Payments do
  require Ash.Query

  alias OdinMarket.Catalog.Listing
  alias OdinMarket.Orders.Order

  @oversold_note "Payment received but the item is out of stock. Refund it in the Stripe dashboard."

  def create_session(orders) when is_list(orders) do
    case api_key() do
      nil ->
        {:error, :not_configured}

      key ->
        orders = Enum.map(orders, &Ash.load!(&1, [:listing, :buyer], authorize?: false))
        first = hd(orders)
        ids = Enum.map_join(orders, ",", & &1.id)

        params =
          %{
            mode: "payment",
            success_url: success_url(first),
            cancel_url: cancel_url(first),
            client_reference_id: first.id,
            metadata: %{order_id: first.id, order_ids: ids},
            line_items: Enum.flat_map(orders, &line_items/1)
          }
          |> maybe_customer(first.buyer)

        case Stripe.Checkout.Session.create(params, api_key: key) do
          {:ok, session} -> {:ok, session.url, session.id}
          {:error, error} -> {:error, error}
        end
    end
  end

  def start_card_setup(user) do
    with {:ok, user} <- ensure_customer(user),
         {:ok, url, _session_id} <- setup_session(user) do
      {:ok, url, user}
    end
  end

  def detach_card(%{stripe_payment_method_id: id}) when is_binary(id) and id != "" do
    case api_key() do
      nil ->
        :ok

      key ->
        case Stripe.PaymentMethod.detach(id, %{}, api_key: key) do
          {:ok, _} -> :ok
          {:error, %{code: code}} when code in ["resource_missing", :resource_missing] -> :ok
          {:error, reason} -> {:error, reason}
        end
    end
  end

  def detach_card(_card), do: :ok

  defp line_items(order) do
    product = %{
      quantity: order.qty,
      price_data: %{
        currency: "aud",
        unit_amount: order.unit_price_cents,
        product_data: %{name: order.listing.title}
      }
    }

    shipping = order.shipping_cents || 0

    if shipping > 0 do
      [
        product,
        %{
          quantity: 1,
          price_data: %{
            currency: "aud",
            unit_amount: shipping,
            product_data: %{name: "Shipping for #{order.listing.title}"}
          }
        }
      ]
    else
      [product]
    end
  end

  defp maybe_customer(params, %{stripe_customer_id: id}) when is_binary(id) and id != "" do
    Map.put(params, :customer, id)
  end

  defp maybe_customer(params, _buyer), do: params

  def ensure_customer(%{stripe_customer_id: id} = user) when is_binary(id) and id != "" do
    {:ok, user}
  end

  def ensure_customer(user) do
    case api_key() do
      nil ->
        {:error, :not_configured}

      key ->
        params = %{
          email: to_string(user.email),
          name: user.display_name,
          metadata: %{user_id: user.id}
        }

        case Stripe.Customer.create(params, api_key: key) do
          {:ok, customer} ->
            Ash.update(user, %{stripe_customer_id: customer.id},
              action: :store_customer,
              actor: user
            )

          {:error, error} ->
            {:error, error}
        end
    end
  end

  defp setup_session(user) do
    case api_key() do
      nil ->
        {:error, :not_configured}

      key ->
        params = %{
          mode: "setup",
          customer: user.stripe_customer_id,
          success_url: "#{OdinMarketWeb.Endpoint.url()}/dashboard/billing?card=saved",
          cancel_url: "#{OdinMarketWeb.Endpoint.url()}/dashboard/billing?card=cancelled",
          metadata: %{user_id: user.id, purpose: "save_card"}
        }

        case Stripe.Checkout.Session.create(params, api_key: key) do
          {:ok, session} -> {:ok, session.url, session.id}
          {:error, error} -> {:error, error}
        end
    end
  end

  def handle_webhook(payload, signature) when is_binary(payload) and is_binary(signature) do
    case webhook_secret() do
      nil ->
        {:error, :bad_signature}

      secret ->
        case Stripe.Webhook.construct_event(payload, signature, secret) do
          {:ok, event} -> apply_event(event)
          {:error, _} -> {:error, :bad_signature}
        end
    end
  end

  def handle_webhook(_payload, _signature), do: {:error, :bad_signature}

  defp apply_event(event) do
    type = event_type(event)
    object = event_object(event)
    mode = session_mode(object)

    cond do
      type == "checkout.session.completed" and mode == "setup" ->
        save_card_from_session(object)

      type == "checkout.session.completed" and mode == "subscription" ->
        OdinMarket.Billing.apply_checkout(object)

      type == "checkout.session.completed" ->
        apply_checkout_completed(object)

      type in [
        "customer.subscription.updated",
        "customer.subscription.deleted",
        "invoice.paid",
        "invoice.payment_failed"
      ] ->
        OdinMarket.Billing.apply_event(type, object)

      true ->
        :ok
    end
  end

  defp save_card_from_session(session) do
    with user_id when is_binary(user_id) and user_id != "" <- session_user_id(session),
         {:ok, %OdinMarket.Accounts.User{} = user} <-
           Ash.get(OdinMarket.Accounts.User, user_id, authorize?: false),
         {:ok, attrs} <- resolve_card(session) do
      case OdinMarket.Accounts.save_card(user, attrs) do
        {:ok, _} -> :ok
        {:error, reason} -> {:error, reason}
      end
    else
      :skip -> :ok
      nil -> :ok
      {:error, reason} -> {:error, reason}
      _ -> :ok
    end
  end

  defp resolve_card(session) do
    case session_payment_method(session) do
      method when is_map(method) ->
        card_from_method(method)

      method when is_binary(method) and method != "" ->
        fetch_payment_method(method)

      _ ->
        case meta_get(session, :setup_intent) do
          intent when is_map(intent) ->
            case meta_get(intent, :payment_method) do
              method when is_map(method) -> card_from_method(method)
              method when is_binary(method) and method != "" -> fetch_payment_method(method)
              _ -> :skip
            end

          id when is_binary(id) and id != "" ->
            fetch_setup_intent(id)

          _ ->
            :skip
        end
    end
  end

  defp card_from_method(method), do: card_attrs(method_id(method), method)

  defp fetch_setup_intent(id) do
    case api_key() do
      nil ->
        {:error, :not_configured}

      key ->
        case Stripe.SetupIntent.retrieve(id, %{}, api_key: key) do
          {:ok, intent} -> resolve_card(%{setup_intent: intent})
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp fetch_payment_method(id) do
    case api_key() do
      nil ->
        {:error, :not_configured}

      key ->
        case Stripe.PaymentMethod.retrieve(id, %{}, api_key: key) do
          {:ok, method} -> card_attrs(method.id, method)
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp card_attrs(id, method) when is_binary(id) and id != "" do
    card = nested_card(method)

    cond do
      is_nil(card) ->
        :skip

      true ->
        last4 = meta_get(card, :last4)
        brand = meta_get(card, :brand) || "card"

        if is_binary(last4) and String.length(last4) == 4 do
          {:ok,
           %{
             stripe_payment_method_id: id,
             brand: brand,
             last4: last4,
             exp_month: meta_get(card, :exp_month),
             exp_year: meta_get(card, :exp_year)
           }}
        else
          :skip
        end
    end
  end

  defp card_attrs(_id, _method), do: :skip

  defp apply_checkout_completed(session) do
    Enum.reduce_while(order_ids(session), :ok, fn id, :ok ->
      case settle_if_pending(id) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp settle_if_pending(id) do
    case Ash.get(Order, id, authorize?: false, load: :listing) do
      {:ok, %Order{status: :pending_payment} = order} -> settle(order)
      {:ok, _} -> :ok
      {:error, _} -> :ok
    end
  end

  def settle(order) do
    order = Ash.load!(order, :listing, authorize?: false)

    result =
      Ash.DataLayer.transaction([Order, Listing], fn ->
        case claim_paid(order.id) do
          {:ok, 0} ->
            :ok

          {:ok, _count} ->
            finish_stock(order)

          {:error, reason} ->
            Ash.DataLayer.rollback(Order, reason)
        end
      end)

    case result do
      {:ok, :ok} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp finish_stock(order) do
    listing = order.listing

    cond do
      listing && listing.kind == :custom ->
        :ok

      true ->
        case decrement_stock(order.listing_id, order.qty) do
          {:ok, 0} ->
            ensure_ok(cancel_claimed(order.id), Order)

          {:ok, _count} ->
            ensure_ok(mark_sold_out_if_empty(order.listing_id), Listing)

          {:error, reason} ->
            Ash.DataLayer.rollback(Listing, reason)
        end
    end
  end

  defp claim_paid(order_id) do
    Order
    |> Ash.Query.filter(id == ^order_id and status == :pending_payment)
    |> run_bulk(:claim_paid, %{})
  end

  defp cancel_claimed(order_id) do
    Order
    |> Ash.Query.filter(id == ^order_id and status == :paid)
    |> run_bulk(:cancel_claimed, %{note: @oversold_note})
  end

  defp decrement_stock(listing_id, qty) do
    Listing
    |> Ash.Query.filter(id == ^listing_id and qty_available >= ^qty)
    |> run_bulk(:decrement_stock, %{qty: qty})
  end

  defp mark_sold_out_if_empty(listing_id) do
    Listing
    |> Ash.Query.filter(id == ^listing_id and qty_available == 0)
    |> run_bulk(:mark_sold_out, %{})
  end

  defp run_bulk(query, action, input) do
    case Ash.bulk_update(query, action, input,
           strategy: [:atomic],
           authorize?: false,
           authorize_query?: false,
           return_records?: true,
           return_errors?: true
         ) do
      %Ash.BulkResult{status: :success, records: records} ->
        {:ok, length(records || [])}

      %Ash.BulkResult{errors: errors} ->
        {:error, errors}
    end
  end

  defp ensure_ok({:ok, _count}, _resource), do: :ok
  defp ensure_ok({:error, reason}, resource), do: Ash.DataLayer.rollback(resource, reason)

  defp success_url(order) do
    "#{OdinMarketWeb.Endpoint.url()}/checkout/success?order_id=#{order.id}&session_id={CHECKOUT_SESSION_ID}"
  end

  defp cancel_url(order) do
    "#{OdinMarketWeb.Endpoint.url()}/checkout/cancel?order_id=#{order.id}"
  end

  defp order_ids(session) do
    meta = session_metadata(session)

    many =
      case meta_get(meta, :order_ids) do
        value when is_binary(value) ->
          value |> String.split(",", trim: true) |> Enum.map(&String.trim/1)

        value when is_list(value) ->
          Enum.map(value, &to_string/1)

        _ ->
          []
      end

    single = meta_get(meta, :order_id)

    [single | many]
    |> Enum.filter(&(is_binary(&1) and &1 != ""))
    |> Enum.uniq()
  end

  defp session_mode(session), do: meta_get(session, :mode)

  defp session_user_id(session) do
    meta_get(session_metadata(session), :user_id)
  end

  defp session_payment_method(session), do: meta_get(session, :payment_method)

  defp method_id(%{id: id}) when is_binary(id), do: id
  defp method_id(%{"id" => id}) when is_binary(id), do: id
  defp method_id(_), do: nil

  defp nested_card(method) when is_map(method) do
    meta_get(method, :card)
  end

  defp nested_card(_), do: nil

  defp session_metadata(session) do
    meta =
      cond do
        is_struct(session) -> Map.get(session, :metadata)
        is_map(session) -> session[:metadata] || session["metadata"]
        true -> nil
      end

    meta || %{}
  end

  defp meta_get(meta, key) when is_map(meta) do
    Map.get(meta, key) || Map.get(meta, Atom.to_string(key))
  end

  defp meta_get(_, _), do: nil

  defp event_type(%{type: type}), do: type
  defp event_type(%{"type" => type}), do: type
  defp event_type(_), do: nil

  defp event_object(%{data: %{object: object}}), do: object
  defp event_object(%{data: %{"object" => object}}), do: object
  defp event_object(%{"data" => %{"object" => object}}), do: object
  defp event_object(_), do: nil

  defp api_key do
    present(Application.get_env(:stripity_stripe, :api_key))
  end

  defp webhook_secret do
    present(Application.get_env(:stripity_stripe, :webhook_secret))
  end

  defp present(value) when is_binary(value) and value != "", do: value
  defp present(_), do: nil
end
