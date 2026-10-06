defmodule OdinMarket.Catalog.Changes.SetStock do
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    kind = Ash.Changeset.get_data(changeset, :kind)
    status = Ash.Changeset.get_data(changeset, :status)
    qty = Ash.Changeset.get_attribute(changeset, :qty_available)

    cond do
      kind != :stock ->
        Ash.Changeset.add_error(changeset,
          field: :qty_available,
          message: "is for stock listings"
        )

      not is_integer(qty) or qty < 0 ->
        Ash.Changeset.add_error(changeset, field: :qty_available, message: "must be zero or more")

      qty == 0 ->
        Ash.Changeset.force_change_attribute(changeset, :status, :sold_out)

      status == :sold_out ->
        Ash.Changeset.force_change_attribute(changeset, :status, :active)

      true ->
        changeset
    end
  end
end
