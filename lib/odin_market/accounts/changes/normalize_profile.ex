defmodule OdinMarket.Accounts.Changes.NormalizeProfile do
  use Ash.Resource.Change

  @shipping [
    :ship_name,
    :ship_line1,
    :ship_line2,
    :ship_city,
    :ship_region,
    :ship_postal_code,
    :ship_country
  ]

  @impl true
  def change(changeset, _opts, _context) do
    changeset
    |> trim(:display_name, required: true)
    |> validate_username()
    |> trim_all(@shipping)
  end

  defp validate_username(changeset) do
    if Ash.Changeset.changing_attribute?(changeset, :username) do
      value = changeset |> Ash.Changeset.get_attribute(:username) |> to_string()

      if Regex.match?(~r/^[A-Za-z0-9_]{3,20}$/, value) do
        case Ash.Type.cast_input(Ash.Type.CiString, value) do
          {:ok, cast} -> Ash.Changeset.force_change_attribute(changeset, :username, cast)
          _ -> username_error(changeset)
        end
      else
        username_error(changeset)
      end
    else
      changeset
    end
  end

  defp username_error(changeset) do
    Ash.Changeset.add_error(changeset,
      field: :username,
      message: "Use 3 to 20 letters, numbers, or underscores."
    )
  end

  defp trim_all(changeset, fields) do
    Enum.reduce(fields, changeset, fn field, changeset -> trim(changeset, field) end)
  end

  defp trim(changeset, field, opts \\ []) do
    value = Ash.Changeset.get_attribute(changeset, field)

    cond do
      not is_binary(value) ->
        changeset

      true ->
        trimmed = value |> String.trim() |> empty_to_nil()

        if opts[:required] && is_nil(trimmed) do
          Ash.Changeset.add_error(changeset, field: field, message: "can't be blank")
        else
          Ash.Changeset.force_change_attribute(changeset, field, trimmed)
        end
    end
  end

  defp empty_to_nil(""), do: nil
  defp empty_to_nil(value), do: value
end
