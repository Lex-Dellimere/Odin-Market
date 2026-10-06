defmodule OdinMarket.Orders.Changes.AdvanceStatus do
  use Ash.Resource.Change

  @next %{
    paid: :in_progress,
    in_progress: :shipped,
    shipped: :complete
  }

  @impl true
  def change(changeset, _opts, _context) do
    current = Ash.Changeset.get_data(changeset, :status)
    requested = Ash.Changeset.get_argument(changeset, :status)

    if Map.get(@next, current) == requested do
      Ash.Changeset.change_attribute(changeset, :status, requested)
    else
      Ash.Changeset.add_error(changeset, field: :status, message: "is not the next status")
    end
  end
end
