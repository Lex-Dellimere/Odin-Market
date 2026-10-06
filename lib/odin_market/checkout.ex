defmodule OdinMarket.Checkout do
  alias OdinMarket.Accounts.Address
  alias OdinMarket.Orders
  alias OdinMarket.Orders.Rules
  alias OdinMarket.Payments

  def start(actor, listing_id, qty, notes) do
    qty = Rules.parse_qty(qty)

    with {:ok, order} <- ensure_order(actor, listing_id, qty, notes),
         {:ok, url, session_id} <- Payments.create_session([order]),
         :ok <- store_sessions([order], session_id) do
      {:ok, url}
    end
  end

  def start_cart(actor) do
    items = if actor, do: Orders.list_cart(actor), else: []

    cond do
      is_nil(actor) ->
        {:error, :unauthenticated}

      items == [] ->
        {:error, :empty_cart}

      not Address.complete?(actor) ->
        {:error, :address_required}

      true ->
        with {:ok, orders} <- ensure_orders(actor, items),
             {:ok, url, session_id} <- Payments.create_session(orders),
             :ok <- store_sessions(orders, session_id) do
          {:ok, url}
        end
    end
  end

  defp ensure_orders(actor, items) do
    Enum.reduce_while(items, {:ok, []}, fn item, {:ok, orders} ->
      case ensure_order(actor, item.listing_id, item.qty, item.notes) do
        {:ok, order} -> {:cont, {:ok, orders ++ [order]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp ensure_order(actor, listing_id, qty, notes) do
    case Orders.find_pending(actor, listing_id) do
      {:ok, nil} ->
        Orders.open(actor, listing_id, qty, notes)

      {:ok, order} ->
        Orders.revise(order, actor, qty, notes)

      {:error, _} = error ->
        error
    end
  end

  defp store_sessions(orders, session_id) do
    Enum.reduce_while(orders, :ok, fn order, :ok ->
      case Orders.store_session(order, session_id) do
        {:ok, _} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end
end
