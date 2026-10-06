defmodule OdinMarket.Catalog.Changes.OwnListingImage do
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, context) do
    listing_id = Ash.Changeset.get_attribute(changeset, :listing_id)
    actor = context.actor

    case OdinMarket.Catalog.get_listing(listing_id) do
      {:ok, listing} ->
        if actor && listing.vendor && listing.vendor.user_id == actor.id do
          changeset
        else
          Ash.Changeset.add_error(changeset, field: :listing_id, message: "is not your listing")
        end

      _ ->
        Ash.Changeset.add_error(changeset, field: :listing_id, message: "was not found")
    end
  end
end
