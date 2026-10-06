defmodule OdinMarket.Chat.Changes.OpenConversation do
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, context) do
    actor = context.actor
    listing_id = Ash.Changeset.get_argument(changeset, :listing_id)

    case OdinMarket.Catalog.get_listing(listing_id) do
      {:ok, listing} ->
        cond do
          is_nil(actor) ->
            Ash.Changeset.add_error(changeset, field: :buyer_id, message: "unauthenticated")

          listing.vendor.user_id == actor.id ->
            Ash.Changeset.add_error(changeset, field: :listing_id, message: "own_listing")

          listing.status != :active or listing.vendor.status != :active ->
            Ash.Changeset.add_error(changeset, field: :listing_id, message: "inactive")

          true ->
            changeset
            |> Ash.Changeset.force_change_attribute(:listing_id, listing.id)
            |> Ash.Changeset.force_change_attribute(:vendor_id, listing.vendor_id)
            |> Ash.Changeset.force_change_attribute(:buyer_id, actor.id)
        end

      _ ->
        Ash.Changeset.add_error(changeset, field: :listing_id, message: "was not found")
    end
  end
end
