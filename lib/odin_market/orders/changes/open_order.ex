defmodule OdinMarket.Orders.Changes.OpenOrder do
  use Ash.Resource.Change

  alias OdinMarket.Orders.Rules

  @impl true
  def change(changeset, _opts, context) do
    actor = context.actor
    listing_id = Ash.Changeset.get_argument(changeset, :listing_id)
    qty = Ash.Changeset.get_argument(changeset, :qty)
    notes = Rules.blank(Ash.Changeset.get_argument(changeset, :notes))

    case OdinMarket.Catalog.get_listing(listing_id) do
      {:ok, listing} ->
        case Rules.eligible(actor, listing, qty) do
          :ok ->
            changeset
            |> Ash.Changeset.force_change_attribute(:listing_id, listing.id)
            |> Ash.Changeset.force_change_attribute(:vendor_id, listing.vendor_id)
            |> Ash.Changeset.force_change_attribute(:buyer_id, actor.id)
            |> Ash.Changeset.force_change_attribute(:qty, qty)
            |> Ash.Changeset.force_change_attribute(:unit_price_cents, listing.price_cents)
            |> Ash.Changeset.force_change_attribute(:shipping_cents, listing.shipping_cents || 0)
            |> Ash.Changeset.force_change_attribute(:currency, "aud")
            |> Ash.Changeset.force_change_attribute(:status, :pending_payment)
            |> Ash.Changeset.force_change_attribute(:notes, notes)
            |> OdinMarket.Accounts.Address.apply(actor)

          {:error, reason} ->
            Ash.Changeset.add_error(changeset, field: :qty, message: Atom.to_string(reason))
        end

      {:error, _reason} ->
        Ash.Changeset.add_error(changeset, field: :listing_id, message: "was not found")
    end
  end
end
