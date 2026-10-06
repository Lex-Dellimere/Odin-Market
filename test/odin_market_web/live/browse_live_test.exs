defmodule OdinMarketWeb.BrowseLiveTest do
  use OdinMarketWeb.ConnCase, async: true

  test "browse shows a matching listing and hides it for another category", %{conn: conn} do
    vendor = register_user(%{role: :vendor, display_name: "Browse Shop"})
    boards = ensure_category("Boards", "boards-browse-#{System.unique_integer([:positive])}")
    sensors = ensure_category("Sensors", "sensors-browse-#{System.unique_integer([:positive])}")

    listing =
      create_listing(vendor, %{
        category_id: boards.id,
        title: "Browseable STM32 board",
        description: "Shown when the query matches STM32"
      })

    {:ok, view, _html} = live(conn, ~p"/browse?q=STM32")
    assert has_element?(view, "#nav-search")
    assert has_element?(view, "#browse-filters")
    assert has_element?(view, "#browse-q")
    assert has_element?(view, "#browse-stock")
    assert has_element?(view, "#browse-results")
    assert has_element?(view, "#listing-#{listing.id} img")

    {:ok, view, _html} = live(conn, ~p"/browse?q=STM32&category_id=#{sensors.id}")
    assert has_element?(view, "#browse-filters")
    assert has_element?(view, "#browse-empty")
    refute has_element?(view, "#listing-#{listing.id}")
  end
end
