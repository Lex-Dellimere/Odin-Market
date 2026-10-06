defmodule OdinMarket.Chat.Changes.SendMessage do
  use Ash.Resource.Change

  require Ash.Query

  @impl true
  def change(changeset, _opts, context) do
    actor = context.actor
    conversation_id = Ash.Changeset.get_attribute(changeset, :conversation_id)
    body = Ash.Changeset.get_attribute(changeset, :body) || ""
    body = String.trim(body)

    changeset =
      changeset
      |> Ash.Changeset.force_change_attribute(:body, body)
      |> Ash.Changeset.force_change_attribute(:sender_id, actor && actor.id)

    case fetch_conversation(conversation_id) do
      {:ok, conversation} ->
        if participant?(actor, conversation) and body != "" do
          changeset
          |> Ash.Changeset.after_action(fn _changeset, message ->
            case touch(conversation) do
              :ok ->
                broadcast(conversation, message)
                {:ok, message}

              {:error, error} ->
                {:error, error}
            end
          end)
        else
          Ash.Changeset.add_error(changeset, field: :body, message: "can't be sent")
        end

      _ ->
        Ash.Changeset.add_error(changeset, field: :conversation_id, message: "was not found")
    end
  end

  defp fetch_conversation(id) do
    OdinMarket.Chat.Conversation
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.load(:vendor)
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, nil} -> :error
      {:ok, conversation} -> {:ok, conversation}
      _ -> :error
    end
  end

  defp participant?(%{id: user_id}, conversation) do
    user_id == conversation.buyer_id or
      (conversation.vendor && conversation.vendor.user_id == user_id)
  end

  defp participant?(_, _), do: false

  defp touch(conversation) do
    case Ash.update(conversation, %{}, action: :touch, authorize?: false) do
      {:ok, _} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  defp broadcast(conversation, message) do
    Phoenix.PubSub.broadcast(
      OdinMarket.PubSub,
      "chat:conv:#{conversation.id}",
      {:message, message}
    )

    Phoenix.PubSub.broadcast(OdinMarket.PubSub, "chat:user:#{conversation.buyer_id}", :inbox)

    if conversation.vendor do
      Phoenix.PubSub.broadcast(
        OdinMarket.PubSub,
        "chat:user:#{conversation.vendor.user_id}",
        :inbox
      )
    end
  end
end
