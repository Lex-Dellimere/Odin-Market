defmodule OdinMarket.Messaging do
  require Ash.Query

  alias OdinMarket.Chat.Conversation
  alias OdinMarket.Chat.Message

  def open_for_listing(actor, listing_id) do
    with {:ok, listing} <- OdinMarket.Catalog.get_listing(listing_id) do
      existing = find_existing(actor, listing)

      cond do
        is_nil(actor) ->
          {:error, :unauthenticated}

        listing.vendor.user_id == actor.id ->
          {:error, :own_listing}

        match?(%Conversation{}, existing) ->
          {:ok, existing}

        listing.status != :active ->
          {:error, :inactive}

        listing.vendor.status != :active or listing.vendor.held ->
          {:error, :suspended}

        true ->
          Ash.create(Conversation, %{listing_id: listing.id}, action: :open, actor: actor)
      end
    end
  end

  def send(actor, conversation_id, body) do
    trimmed = String.trim(to_string(body || ""))

    cond do
      trimmed == "" ->
        {:error, :blank}

      String.length(trimmed) > 2000 ->
        {:error, :too_long}

      true ->
        Ash.create(Message, %{conversation_id: conversation_id, body: trimmed},
          action: :send,
          actor: actor
        )
    end
  end

  def inbox(user) do
    Conversation
    |> Ash.Query.filter(buyer_id == ^user.id or vendor.user_id == ^user.id)
    |> Ash.Query.load([:listing, :buyer, vendor: :user])
    |> Ash.Query.sort(updated_at: :desc)
    |> Ash.read!(authorize?: false)
  end

  def get_thread(user, id) do
    case Ecto.UUID.cast(to_string(id)) do
      {:ok, uuid} ->
        case Ash.get(Conversation, uuid,
               authorize?: false,
               load: [:listing, :buyer, vendor: :user, messages: :sender]
             ) do
          {:ok, %Conversation{} = conversation} ->
            if participant?(user, conversation) do
              mark_read(conversation.id, user.id)
              {:ok, conversation}
            else
              {:error, :not_found}
            end

          _ ->
            {:error, :not_found}
        end

      _ ->
        {:error, :not_found}
    end
  end

  def unread_count(nil), do: 0

  def unread_count(%{id: user_id}) do
    ids =
      Conversation
      |> Ash.Query.filter(buyer_id == ^user_id or vendor.user_id == ^user_id)
      |> Ash.read!(authorize?: false)
      |> Enum.map(& &1.id)

    if ids == [] do
      0
    else
      Message
      |> Ash.Query.filter(conversation_id in ^ids and sender_id != ^user_id and is_nil(read_at))
      |> Ash.count!(authorize?: false)
    end
  end

  def mark_read(conversation_id, user_id) do
    Message
    |> Ash.Query.filter(
      conversation_id == ^conversation_id and sender_id != ^user_id and is_nil(read_at)
    )
    |> Ash.bulk_update(:mark_read, %{},
      strategy: [:atomic],
      authorize?: false,
      authorize_query?: false,
      return_errors?: true
    )
  end

  defp find_existing(nil, _listing), do: nil

  defp find_existing(actor, listing) do
    Conversation
    |> Ash.Query.filter(
      buyer_id == ^actor.id and vendor_id == ^listing.vendor_id and listing_id == ^listing.id
    )
    |> Ash.read_one!(authorize?: false)
  end

  defp participant?(%{id: user_id}, conversation) do
    user_id == conversation.buyer_id or
      (conversation.vendor && conversation.vendor.user_id == user_id)
  end

  defp participant?(_, _), do: false
end
