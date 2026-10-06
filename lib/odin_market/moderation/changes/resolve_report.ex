defmodule OdinMarket.Moderation.Changes.ResolveReport do
  use Ash.Resource.Change

  @impl true
  def change(changeset, opts, %{actor: %{id: actor_id}}) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    note =
      case Ash.Changeset.get_attribute(changeset, :resolution_note) do
        value when is_binary(value) -> value |> String.trim() |> String.slice(0, 500)
        _ -> ""
      end

    note = if note == "", do: nil, else: note

    changeset
    |> Ash.Changeset.force_change_attribute(:status, opts[:status])
    |> Ash.Changeset.force_change_attribute(:resolution_note, note)
    |> Ash.Changeset.force_change_attribute(:handler_id, actor_id)
    |> Ash.Changeset.force_change_attribute(:handled_at, now)
  end

  def change(changeset, _opts, _context) do
    Ash.Changeset.add_error(changeset, field: :status, message: "Sign in to update a report.")
  end
end
