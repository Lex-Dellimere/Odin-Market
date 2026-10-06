defmodule OdinMarketWeb.ListingLiveTest do
  use OdinMarketWeb.ConnCase, async: true

  test "a listing shows its photo and buy form", %{conn: conn} do
    vendor = register_user(%{role: :vendor, display_name: "Photo Shop"})
    category = ensure_category("Boards", "boards-listing-#{System.unique_integer([:positive])}")

    listing =
      create_listing(vendor, %{
        category_id: category.id,
        title: "Photo STM32 board",
        qty_available: 4
      })

    {:ok, view, _html} = live(conn, ~p"/l/#{listing.slug}")

    assert has_element?(view, "#listing")
    assert has_element?(view, "#listing img")
    assert has_element?(view, "#buy-form")
    assert has_element?(view, "#message-seller")
  end
end
