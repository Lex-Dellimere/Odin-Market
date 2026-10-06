defmodule OdinMarket.Orders.Changes.UpdateCartLine do
  use Ash.Resource.Change

  alias OdinMarket.Orders.Rules

  @impl true
  def change(changeset, _opts, context) do
    actor = context.actor
    listing_id = Ash.Changeset.get_data(changeset, :listing_id)
    notes = Rules.blank(Ash.Changeset.get_argument(changeset, :notes))

    case OdinMarket.Catalog.get_listing(listing_id) do
      {:ok, listing} ->
        qty = line_qty(listing, Ash.Changeset.get_argument(changeset, :qty))

        case Rules.eligible(actor, listing, qty) do
          :ok ->
            changeset
            |> Ash.Changeset.force_change_attribute(:qty, qty)
            |> Ash.Changeset.force_change_attribute(:notes, notes)

          {:error, reason} ->
            Ash.Changeset.add_error(changeset, field: :qty, message: Atom.to_string(reason))
        end

      _ ->
        Ash.Changeset.add_error(changeset, field: :listing_id, message: "was not found")
    end
  end

  defp line_qty(%{kind: :custom}, _qty), do: 1
  defp line_qty(_listing, qty), do: Rules.parse_qty(qty)
end
