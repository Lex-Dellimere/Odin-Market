defmodule OdinMarket.Accounts.Changes.NormalizeWebsite do
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :website) do
      nil ->
        changeset

      value ->
        trimmed = value |> to_string() |> String.trim()

        cond do
          trimmed == "" ->
            Ash.Changeset.force_change_attribute(changeset, :website, nil)

          String.starts_with?(trimmed, "http://") or String.starts_with?(trimmed, "https://") ->
            Ash.Changeset.force_change_attribute(changeset, :website, trimmed)

          true ->
            Ash.Changeset.add_error(changeset,
              field: :website,
              message: "must start with http:// or https://"
            )
        end
    end
  end
end
