defmodule OdinMarket.Orders.Changes.ReviseOrder do
  use Ash.Resource.Change

  alias OdinMarket.Orders.Rules

  @impl true
  def change(changeset, _opts, context) do
    actor = context.actor
    qty = Ash.Changeset.get_argument(changeset, :qty)
    notes = Rules.blank(Ash.Changeset.get_argument(changeset, :notes))
    status = Ash.Changeset.get_data(changeset, :status)
    listing_id = Ash.Changeset.get_data(changeset, :listing_id)

    cond do
      status != :pending_payment ->
        Ash.Changeset.add_error(changeset,
          field: :status,
          message: "is no longer awaiting payment"
        )

      true ->
        case OdinMarket.Catalog.get_listing(listing_id) do
          {:ok, listing} ->
            case Rules.eligible(actor, listing, qty) do
              :ok ->
                changeset
                |> Ash.Changeset.force_change_attribute(:qty, qty)
                |> Ash.Changeset.force_change_attribute(:notes, notes)
                |> Ash.Changeset.force_change_attribute(:unit_price_cents, listing.price_cents)
                |> Ash.Changeset.force_change_attribute(
                  :shipping_cents,
                  listing.shipping_cents || 0
                )
                |> OdinMarket.Accounts.Address.apply(actor)

              {:error, reason} ->
                Ash.Changeset.add_error(changeset, field: :qty, message: Atom.to_string(reason))
            end

          _ ->
            Ash.Changeset.add_error(changeset, field: :listing_id, message: "was not found")
        end
    end
  end
end
