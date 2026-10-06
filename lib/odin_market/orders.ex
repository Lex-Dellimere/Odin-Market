defmodule OdinMarket.Orders do
  use Ash.Domain, otp_app: :odin_market, extensions: [AshAdmin.Domain]

  require Ash.Query

  alias OdinMarket.Orders.CartItem
  alias OdinMarket.Orders.Order
  alias OdinMarket.Orders.Rules

  admin do
    show? true
  end

  resources do
    resource Order
    resource CartItem
  end

  def open(actor, listing_id, qty, notes) do
    qty = Rules.parse_qty(qty)

    with {:ok, listing} <- OdinMarket.Catalog.get_listing(listing_id),
         :ok <- Rules.eligible(actor, listing, qty) do
      Ash.create(Order, %{listing_id: listing.id, qty: qty, notes: notes},
        action: :open,
        actor: actor
      )
    end
  end

  def revise(order, actor, qty, notes) do
    qty = Rules.parse_qty(qty)

    with {:ok, listing} <- OdinMarket.Catalog.get_listing(order.listing_id),
         :ok <- Rules.eligible(actor, listing, qty) do
      Ash.update(order, %{qty: qty, notes: notes}, action: :revise, actor: actor)
    end
  end

  def find_pending(actor, listing_id) when not is_nil(actor) do
    case Ecto.UUID.cast(to_string(listing_id)) do
      {:ok, uuid} ->
        Order
        |> Ash.Query.filter(
          buyer_id == ^actor.id and listing_id == ^uuid and status == :pending_payment
        )
        |> Ash.Query.limit(1)
        |> Ash.read_one(authorize?: false)

      _ ->
        {:ok, nil}
    end
  end

  def find_pending(_actor, _listing_id), do: {:ok, nil}

  def list_for_buyer(user) do
    Order
    |> Ash.Query.filter(buyer_id == ^user.id)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.load([:listing, :vendor])
    |> Ash.read!(actor: user)
  end

  def list_for_vendor(profile, actor) do
    Order
    |> Ash.Query.filter(vendor_id == ^profile.id and status != :pending_payment)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.load([:listing, :buyer])
    |> Ash.read!(actor: actor)
  end

  def get_order(user, id) do
    case Ecto.UUID.cast(to_string(id)) do
      {:ok, uuid} ->
        case Ash.get(Order, uuid, actor: user, load: [:listing, :vendor, :buyer]) do
          {:ok, nil} -> {:error, :not_found}
          {:ok, order} -> {:ok, order}
          {:error, _} -> {:error, :not_found}
        end

      _ ->
        {:error, :not_found}
    end
  end

  def advance(order, actor, status) do
    Ash.update(order, %{status: status}, action: :advance, actor: actor)
  end

  def store_session(order, session_id) do
    Ash.update(order, %{stripe_checkout_session_id: session_id},
      action: :store_session,
      authorize?: false
    )
  end

  def add_to_cart(actor, listing_id, qty, notes) do
    case Ecto.UUID.cast(to_string(listing_id)) do
      {:ok, uuid} ->
        CartItem
        |> Ash.create(%{listing_id: uuid, qty: qty, notes: notes}, action: :add, actor: actor)
        |> unwrap_cart()

      _ ->
        {:error, :not_found}
    end
  end

  def update_cart_line(item, actor, qty, notes) do
    item
    |> Ash.update(%{qty: qty, notes: notes}, action: :update_line, actor: actor)
    |> unwrap_cart()
  end

  def remove_cart_line(item, actor) do
    Ash.destroy(item, actor: actor)
  end

  def list_cart(user) do
    CartItem
    |> Ash.Query.filter(buyer_id == ^user.id)
    |> Ash.Query.sort(inserted_at: :asc)
    |> Ash.Query.load(listing: [:images, :vendor])
    |> Ash.read!(actor: user)
  end

  def cart_count(nil), do: 0

  def cart_count(%{id: user_id}) do
    CartItem
    |> Ash.Query.filter(buyer_id == ^user_id)
    |> Ash.count!(authorize?: false)
  end

  @cart_reasons ~w(own_listing inactive above_stock bad_qty unauthenticated not_found)

  defp unwrap_cart({:ok, result}), do: {:ok, result}

  defp unwrap_cart({:error, %Ash.Error.Invalid{errors: errors}}) do
    reason =
      Enum.find_value(errors, :invalid, fn error ->
        message = Map.get(error, :message)

        if message in @cart_reasons do
          String.to_existing_atom(message)
        end
      end)

    {:error, reason}
  end

  defp unwrap_cart({:error, _}), do: {:error, :invalid}

  def next_status(:paid), do: :in_progress
  def next_status(:in_progress), do: :shipped
  def next_status(:shipped), do: :complete
  def next_status(_), do: nil
end
