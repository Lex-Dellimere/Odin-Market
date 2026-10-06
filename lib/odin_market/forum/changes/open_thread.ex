defmodule OdinMarket.Forum.Changes.OpenThread do
  use Ash.Resource.Change

  alias OdinMarket.Forum.Post

  @impl true
  def change(changeset, _opts, %{actor: actor}) do
    body = Ash.Changeset.get_argument(changeset, :body)

    changeset
    |> Ash.Changeset.force_change_attribute(:author_id, actor && actor.id)
    |> Ash.Changeset.after_action(fn _changeset, thread ->
      case Ash.create(
             Post,
             %{thread_id: thread.id, body: body, author_id: actor.id, opening: true},
             action: :create_opening,
             authorize?: false
           ) do
        {:ok, _post} -> {:ok, thread}
        {:error, error} -> {:error, error}
      end
    end)
  end
end
