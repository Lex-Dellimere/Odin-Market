defmodule OdinMarket.CatalogTest do
  use OdinMarket.DataCase, async: true

  alias OdinMarket.Catalog
  alias OdinMarket.Catalog.Category
  alias OdinMarket.Catalog.Listing

  test "a draft listing is hidden from the public slug lookup" do
    vendor = register_user(%{role: :vendor, display_name: "Nordic"})
    category = ensure_category("Boards", "boards-#{System.unique_integer([:positive])}")

    listing =
      create_listing(vendor, %{
        category_id: category.id,
        status: :draft,
        title: "Secret gate driver"
      })

    assert {:error, :not_found} = OdinMarket.Catalog.get_by_slug(listing.slug)
  end

  test "a vendor cannot update another shop's listing" do
    owner = register_user(%{role: :vendor, display_name: "Owner"})
    other = register_user(%{role: :vendor, display_name: "Other"})
    category = ensure_category("Sensors", "sensors-#{System.unique_integer([:positive])}")
    listing = create_listing(owner, %{category_id: category.id, title: "Owned sensor"})

    assert {:error, %Ash.Error.Forbidden{}} =
             Ash.update(listing, %{title: "Stolen"}, action: :save, actor: other)
  end

  test "a family category includes its kinds, and a listing must pick a kind" do
    vendor = register_user(%{role: :vendor, display_name: "Radio Shop"})
    n = System.unique_integer([:positive])
    parent = ensure_category("Radio", "radio-#{n}")

    {:ok, child} =
      Ash.create(
        Category,
        %{name: "HF radio", slug: "radio-hf-#{n}", parent_id: parent.id},
        action: :create,
        authorize?: false
      )

    listing =
      create_listing(vendor, %{
        category_id: child.id,
        title: "HF handheld #{n}",
        description: "A 5 watt handheld."
      })

    assert {:ok, %{results: results}} = Catalog.search(%{"category_id" => parent.id})
    assert Enum.any?(results, &(&1.id == listing.id))

    assert {:ok, %{results: specific}} = Catalog.search(%{"category_id" => child.id})
    assert Enum.any?(specific, &(&1.id == listing.id))

    assert {:error, %Ash.Error.Invalid{}} =
             Ash.create(
               Listing,
               %{
                 title: "Whole family",
                 description: "Too broad",
                 kind: :stock,
                 price_cents: 1000,
                 qty_available: 1,
                 category_id: parent.id,
                 status: :active
               },
               action: :publish,
               actor: vendor
             )

    assert {:error, %Ash.Error.Invalid{}} =
             Ash.create(
               Listing,
               %{
                 title: "No words",
                 description: "   ",
                 kind: :stock,
                 price_cents: 1000,
                 qty_available: 1,
                 category_id: child.id,
                 status: :draft
               },
               action: :publish,
               actor: vendor
             )
  end
end
