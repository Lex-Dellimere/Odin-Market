defmodule OdinMarket.Moderation.Changes.FileReport do
  use Ash.Resource.Change

  require Ash.Query

  alias OdinMarket.Accounts.User
  alias OdinMarket.Catalog.Listing
  alias OdinMarket.Chat.Message
  alias OdinMarket.Forum.Post
  alias OdinMarket.Forum.Thread
  alias OdinMarket.Moderation.Report

  @impl true
  def change(changeset, _opts, %{actor: %{id: actor_id} = actor}) do
    type = Ash.Changeset.get_attribute(changeset, :target_type)
    target_id = Ash.Changeset.get_attribute(changeset, :target_id)
    note = clip(Ash.Changeset.get_attribute(changeset, :note), 500)
    note = if note == "", do: nil, else: note

    changeset = Ash.Changeset.force_change_attribute(changeset, :note, note)

    cond do
      duplicate?(actor_id, type, target_id) ->
        error(changeset, "You already reported this.")

      true ->
        case lookup(actor, type, target_id) do
          {:ok, excerpt, subject_id, subject_name} ->
            changeset
            |> Ash.Changeset.force_change_attribute(:reporter_id, actor_id)
            |> Ash.Changeset.force_change_attribute(:reporter_name, username(actor))
            |> Ash.Changeset.force_change_attribute(:subject_id, subject_id)
            |> Ash.Changeset.force_change_attribute(:subject_name, subject_name)
            |> Ash.Changeset.force_change_attribute(:excerpt, excerpt)
            |> Ash.Changeset.force_change_attribute(:status, :open)

          {:error, message} ->
            error(changeset, message)
        end
    end
  end

  def change(changeset, _opts, _context) do
    error(changeset, "Sign in to report.")
  end

  defp lookup(actor, :forum_post, id) do
    case Ash.get(Post, id, authorize?: false) do
      {:ok, %Post{author_id: author_id}} when author_id == actor.id ->
        {:error, "You cannot report your own post."}

      {:ok, %Post{} = post} ->
        {:ok, clip(post.body, 280), post.author_id, name_of(post.author_id)}

      _ ->
        {:error, "That is not available to report."}
    end
  end

  defp lookup(actor, :forum_thread, id) do
    case Ash.get(Thread, id, authorize?: false) do
      {:ok, %Thread{author_id: author_id}} when author_id == actor.id ->
        {:error, "You cannot report your own thread."}

      {:ok, %Thread{} = thread} ->
        {:ok, clip(thread.title, 280), thread.author_id, name_of(thread.author_id)}

      _ ->
        {:error, "That is not available to report."}
    end
  end

  defp lookup(actor, :message, id) do
    case Ash.get(Message, id, authorize?: false, load: [conversation: :vendor]) do
      {:ok, %Message{sender_id: sender_id} = message} ->
        conversation = message.conversation

        cond do
          not participant?(actor, conversation) ->
            {:error, "That is not available to report."}

          sender_id == actor.id ->
            {:error, "You cannot report your own message."}

          true ->
            {:ok, clip(message.body, 280), sender_id, name_of(sender_id)}
        end

      _ ->
        {:error, "That is not available to report."}
    end
  end

  defp lookup(actor, :listing, id) do
    case Ash.get(Listing, id, authorize?: false, load: :vendor) do
      {:ok, %Listing{vendor: %{user_id: user_id}}} when user_id == actor.id ->
        {:error, "You cannot report your own listing."}

      {:ok,
       %Listing{status: :active, vendor: %{status: :active, held: false, user_id: user_id}} =
           listing} ->
        {:ok, clip(listing.title, 280), user_id, name_of(user_id)}

      _ ->
        {:error, "That is not available to report."}
    end
  end

  defp lookup(actor, :user, id) do
    case Ash.get(User, id, authorize?: false) do
      {:ok, %User{id: user_id}} when user_id == actor.id ->
        {:error, "You cannot report your own account."}

      {:ok, %User{deleted_at: nil} = user} ->
        {:ok, username(user), user.id, username(user)}

      _ ->
        {:error, "That is not available to report."}
    end
  end

  defp lookup(_actor, _type, _id), do: {:error, "That is not available to report."}

  defp participant?(actor, %{buyer_id: buyer_id, vendor: %{user_id: vendor_user_id}}) do
    actor.id == buyer_id or actor.id == vendor_user_id
  end

  defp participant?(_actor, _conversation), do: false

  defp duplicate?(reporter_id, type, target_id) do
    Report
    |> Ash.Query.filter(
      reporter_id == ^reporter_id and target_type == ^type and target_id == ^target_id and
        status == :open
    )
    |> Ash.exists?(authorize?: false)
  end

  defp name_of(nil), do: "Member"

  defp name_of(id) do
    case Ash.get(User, id, authorize?: false) do
      {:ok, user} when not is_nil(user) -> username(user)
      _ -> "Member"
    end
  end

  defp username(%{username: name}) when not is_nil(name), do: to_string(name)
  defp username(_), do: "Member"

  defp clip(nil, _max), do: ""

  defp clip(value, max) do
    value
    |> to_string()
    |> String.trim()
    |> String.slice(0, max)
  end

  defp error(changeset, message) do
    Ash.Changeset.add_error(changeset, field: :target_id, message: message)
  end
end
