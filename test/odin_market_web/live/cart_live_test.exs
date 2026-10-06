defmodule OdinMarketWeb.CartLiveTest do
  use OdinMarketWeb.ConnCase, async: true

  alias OdinMarket.Accounts
  alias OdinMarket.Orders

  setup %{conn: conn} do
    vendor = register_user(%{role: :vendor, display_name: "Volt Foundry"})
    buyer = register_user(%{display_name: "Ada"})
    category = ensure_category("Boards", "boards-cart-#{System.unique_integer([:positive])}")

    listing =
      create_listing(vendor, %{
        category_id: category.id,
        title: "Cart STM32 board",
        qty_available: 4,
        price_cents: 500
      })

    %{
      conn: conn,
      vendor: vendor,
      buyer: buyer,
      listing: listing,
      category: category
    }
  end

  test "a buyer adds a listing, edits the cart, and saves an address", %{
    conn: conn,
    buyer: buyer,
    listing: listing
  } do
    conn = log_in(conn, buyer)
    {:ok, view, _html} = live(conn, ~p"/l/#{listing.slug}")

    {:ok, cart, html} =
      view
      |> form("#buy-form", %{"buy" => %{"qty" => "2"}})
      |> render_submit()
      |> follow_redirect(conn, ~p"/cart")

    assert html =~ "Cart STM32 board"
    assert html =~ "A$10.00"
    assert has_element?(cart, "#cart-lines")
    assert has_element?(cart, "#cart-address")
    assert has_element?(cart, "#pay-cart")
    assert has_element?(cart, "#cart-badge", "1")

    [item] = Orders.list_cart(buyer)

    cart
    |> form("#cart-line-#{item.id}", %{"line" => %{"qty" => "1"}})
    |> render_submit(%{"id" => item.id})

    assert render(cart) =~ "A$5.00"

    html =
      cart
      |> form("#cart-address", %{
        "profile" => %{
          "display_name" => "Ada",
          "ship_name" => "Ada Lovelace",
          "ship_line1" => "1 Bench Street",
          "ship_city" => "Oslo",
          "ship_country" => "Norway"
        }
      })
      |> render_submit(%{"intent" => "save"})

    assert html =~ "Shipping address saved"

    cart
    |> element("#cart-item-#{item.id} button", "Remove")
    |> render_click()

    assert has_element?(cart, "#cart-empty")
    refute has_element?(cart, "#pay-cart")
  end

  test "paying without an address stays on the cart", %{
    conn: conn,
    buyer: buyer,
    listing: listing
  } do
    assert {:ok, _} = Orders.add_to_cart(buyer, listing.id, 1, nil)
    conn = log_in(conn, buyer)
    {:ok, cart, _html} = live(conn, ~p"/cart")

    html =
      cart
      |> form("#cart-address", %{
        "profile" => %{"display_name" => "Ada", "ship_name" => "", "ship_city" => ""}
      })
      |> render_submit(%{"intent" => "pay"})

    assert html =~ "Add a recipient"
    assert {:ok, nil} = Orders.find_pending(buyer, listing.id)
  end

  test "the account form updates the shipping address", %{conn: conn, buyer: buyer} do
    conn = log_in(conn, buyer)
    {:ok, settings, html} = live(conn, ~p"/dashboard/settings")
    assert has_element?(settings, "#account-form")
    assert html =~ to_string(buyer.email)

    settings
    |> form("#account-form", %{
      "profile" => %{
        "username" => to_string(buyer.username),
        "display_name" => "Ada Bench"
      }
    })
    |> render_submit()

    {:ok, view, _html} = live(conn, ~p"/dashboard/billing")

    view
    |> form("#address-form", %{
      "profile" => %{
        "ship_name" => "Ada Bench",
        "ship_line1" => "2 Harbor Road",
        "ship_city" => "Bergen",
        "ship_country" => "Norway"
      }
    })
    |> render_submit()

    assert render(view) =~ "Account updated"
    {:ok, user} = Ash.get(OdinMarket.Accounts.User, buyer.id, authorize?: false)
    assert user.display_name == "Ada Bench"
    assert user.ship_line1 == "2 Harbor Road"
    assert user.ship_city == "Bergen"
  end

  test "a saved order shows the address copied at checkout", %{
    conn: conn,
    buyer: buyer,
    listing: listing
  } do
    {:ok, buyer} =
      Accounts.save_profile(buyer, %{
        "display_name" => "Ada",
        "ship_name" => "Ada Lovelace",
        "ship_line1" => "1 Bench Street",
        "ship_city" => "Oslo",
        "ship_country" => "Norway"
      })

    {:ok, order} = Orders.open(buyer, listing.id, 1, nil)
    conn = log_in(conn, buyer)
    {:ok, view, html} = live(conn, ~p"/dashboard/orders/#{order.id}")

    assert has_element?(view, "#order")
    assert has_element?(view, "#shipping-address")
    assert html =~ "1 Bench Street"
    assert html =~ "A$5.00"
  end

  test "the shop form saves a website and the public shop links it", %{
    conn: conn,
    vendor: vendor
  } do
    profile = Accounts.profile_for(vendor)
    conn = log_in(conn, vendor)
    {:ok, view, _html} = live(conn, ~p"/dashboard/shop")

    html =
      view
      |> form("#shop-form", %{
        "shop" => %{
          "shop_name" => profile.shop_name,
          "bio" => "Power boards",
          "location" => "Bergen",
          "website" => "javascript:alert(1)"
        }
      })
      |> render_submit()

    assert html =~ "must start with http"

    view
    |> form("#shop-form", %{
      "shop" => %{
        "shop_name" => "Volt Foundry",
        "bio" => "Power boards",
        "location" => "Bergen",
        "website" => "https://volt.example"
      }
    })
    |> render_submit()

    assert render(view) =~ "Shop updated"

    {:ok, shop, html} = live(conn, ~p"/shop/#{profile.slug}")
    assert has_element?(shop, "#shop-website")
    assert html =~ "https://volt.example"
    assert html =~ "Bergen"
  end

  test "a vendor edits a listing from the shop form", %{
    conn: conn,
    vendor: vendor,
    listing: listing
  } do
    conn = log_in(conn, vendor)
    {:ok, view, html} = live(conn, ~p"/dashboard/listings/#{listing.id}/edit")
    assert has_element?(view, "textarea[name='listing[description]']")
    assert has_element?(view, "select[name='listing[category_id]']")
    assert has_element?(view, "input[name='listing[price_cents]']")
    assert has_element?(view, "#listing-photos")
    assert html =~ "Description"
    assert html =~ "Category"
    assert html =~ "Price (cents)"

    {:ok, index, html} =
      view
      |> form("#listing-form", %{
        "listing" => %{"title" => "Renamed STM32 board", "price_cents" => "750"}
      })
      |> render_submit()
      |> follow_redirect(conn, ~p"/dashboard/listings")

    assert has_element?(index, "#vendor-listings")
    assert html =~ "Renamed STM32 board"
    assert html =~ "A$7.50"

    {:ok, saved} = OdinMarket.Catalog.get_owned(listing.id, vendor)
    assert saved.title == "Renamed STM32 board"
    assert saved.price_cents == 750
  end
end
