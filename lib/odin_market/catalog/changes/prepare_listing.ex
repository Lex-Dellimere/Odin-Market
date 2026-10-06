defmodule OdinMarket.Catalog.Changes.PrepareListing do
  use Ash.Resource.Change

  require Ash.Query

  alias OdinMarket.Catalog.Category

  @spec_keys [:voltage, :package, :interface, :mcu]

  @impl true
  def change(changeset, _opts, context) do
    changeset
    |> put_vendor(context.actor)
    |> reject_hold(context.actor)
    |> require_description()
    |> require_specific_category()
    |> put_specs()
    |> put_status()
    |> put_shipping()
    |> normalize_kind()
    |> Ash.Changeset.force_change_attribute(:currency, "aud")
  end

  defp require_description(changeset) do
    case Ash.Changeset.get_attribute(changeset, :description) do
      text when is_binary(text) ->
        trimmed = String.trim(text)

        if trimmed == "" do
          Ash.Changeset.add_error(changeset, field: :description, message: "is required")
        else
          Ash.Changeset.force_change_attribute(changeset, :description, trimmed)
        end

      _ ->
        Ash.Changeset.add_error(changeset, field: :description, message: "is required")
    end
  end

  defp require_specific_category(changeset) do
    case Ash.Changeset.get_attribute(changeset, :category_id) do
      id when is_binary(id) ->
        has_children? =
          Category
          |> Ash.Query.filter(parent_id == ^id)
          |> Ash.exists?(authorize?: false)

        if has_children? do
          Ash.Changeset.add_error(changeset,
            field: :category_id,
            message: "choose a specific category"
          )
        else
          changeset
        end

      _ ->
        Ash.Changeset.add_error(changeset, field: :category_id, message: "choose a category")
    end
  end

  defp reject_hold(changeset, actor) do
    case OdinMarket.Accounts.profile_for(actor) do
      %{held: true} ->
        Ash.Changeset.add_error(changeset, field: :vendor_id, message: "This shop is on hold.")

      _ ->
        changeset
    end
  end

  defp put_vendor(changeset, actor) do
    if changeset.action_type == :create do
      case OdinMarket.Accounts.profile_for(actor) do
        %{id: id} ->
          Ash.Changeset.force_change_attribute(changeset, :vendor_id, id)

        _ ->
          Ash.Changeset.add_error(changeset,
            field: :vendor_id,
            message: "vendor profile required"
          )
      end
    else
      changeset
    end
  end

  defp put_specs(changeset) do
    specs =
      Enum.reduce(@spec_keys, %{}, fn key, acc ->
        value = Ash.Changeset.get_argument(changeset, key)

        if is_binary(value) and String.trim(value) != "" do
          Map.put(acc, Atom.to_string(key), String.trim(value))
        else
          acc
        end
      end)

    Ash.Changeset.force_change_attribute(changeset, :specs, specs)
  end

  defp put_status(changeset) do
    case Ash.Changeset.get_argument(changeset, :status) do
      status when status in [:draft, :active] ->
        Ash.Changeset.force_change_attribute(changeset, :status, status)

      _ ->
        changeset
    end
  end

  defp put_shipping(changeset) do
    case Ash.Changeset.get_attribute(changeset, :shipping_cents) do
      cents when is_integer(cents) -> changeset
      _ -> Ash.Changeset.force_change_attribute(changeset, :shipping_cents, 0)
    end
  end

  defp normalize_kind(changeset) do
    case Ash.Changeset.get_attribute(changeset, :kind) do
      :stock ->
        changeset
        |> Ash.Changeset.force_change_attribute(:lead_days, nil)
        |> require_qty()

      :custom ->
        changeset
        |> Ash.Changeset.force_change_attribute(:qty_available, nil)
        |> require_lead()

      _ ->
        Ash.Changeset.add_error(changeset, field: :kind, message: "pick stock or custom")
    end
  end

  defp require_qty(changeset) do
    case Ash.Changeset.get_attribute(changeset, :qty_available) do
      qty when is_integer(qty) and qty >= 0 -> changeset
      _ -> Ash.Changeset.add_error(changeset, field: :qty_available, message: "is required")
    end
  end

  defp require_lead(changeset) do
    case Ash.Changeset.get_attribute(changeset, :lead_days) do
      days when is_integer(days) and days >= 1 -> changeset
      _ -> Ash.Changeset.add_error(changeset, field: :lead_days, message: "is required")
    end
  end
end
