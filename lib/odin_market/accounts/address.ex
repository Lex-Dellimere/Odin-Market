defmodule OdinMarket.Accounts.Address do
  @moduledoc false

  @fields [
    :ship_name,
    :ship_line1,
    :ship_line2,
    :ship_city,
    :ship_region,
    :ship_postal_code,
    :ship_country
  ]

  def fields, do: @fields

  def complete?(record) when is_map(record) do
    present?(Map.get(record, :ship_name)) and present?(Map.get(record, :ship_line1)) and
      present?(Map.get(record, :ship_city)) and present?(Map.get(record, :ship_country))
  end

  def complete?(_), do: false

  def apply(changeset, record) when is_map(record) do
    Enum.reduce(@fields, changeset, fn field, changeset ->
      Ash.Changeset.force_change_attribute(
        changeset,
        field,
        present_or_nil(Map.get(record, field))
      )
    end)
  end

  def present?(value) when is_binary(value), do: String.trim(value) != ""
  def present?(_), do: false

  defp present_or_nil(value) do
    if present?(value), do: String.trim(value), else: nil
  end
end
