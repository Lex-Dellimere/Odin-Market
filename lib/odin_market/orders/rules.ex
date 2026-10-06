defmodule OdinMarket.Orders.Rules do
  def eligible(actor, listing, qty) do
    vendor = listing.vendor

    cond do
      is_nil(actor) ->
        {:error, :unauthenticated}

      is_nil(vendor) or listing.status != :active or vendor.status != :active ->
        {:error, :inactive}

      vendor.user_id == actor.id ->
        {:error, :own_listing}

      not is_integer(qty) or qty < 1 ->
        {:error, :bad_qty}

      listing.kind == :stock and qty > (listing.qty_available || 0) ->
        {:error, :above_stock}

      true ->
        :ok
    end
  end

  def blank(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  def blank(_), do: nil

  def parse_qty(value) when is_integer(value), do: value

  def parse_qty(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {qty, ""} -> qty
      _ -> nil
    end
  end

  def parse_qty(_), do: nil
end
