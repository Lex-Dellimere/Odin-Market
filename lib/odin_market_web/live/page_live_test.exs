defmodule OdinMarketWeb.PageLiveTest do
  use OdinMarketWeb.ConnCase, async: true

  test "the empty homepage, privacy, and terms are public", %{conn: conn} do
    {:ok, home, home_html} = live(conn, ~p"/")
    refute has_element?(home, "#home-search")
    assert has_element?(home, "#home-hero")
    assert has_element?(home, "#hero-browse")
    assert has_element?(home, "#hero-sell")
    assert has_element?(home, "#how-it-works")
    assert has_element?(home, "#for-vendors")
    assert has_element?(home, "#home-empty")
    assert has_element?(home, "#nav-links")
    assert has_element?(home, "#nav-account-actions")
    assert home_html =~ "No listings yet"
    assert home_html =~ "Make what you have in mind."
    assert home_html =~ "Odin Market"

    for {id, href} <- [
          {"nav-browse", "/browse"},
          {"nav-open-dashboard", "/vendor"},
          {"nav-sign-in", "/sign-in"},
          {"nav-register", "/register"},
          {"footer-privacy", "/privacy"},
          {"footer-terms", "/terms"}
        ] do
      assert has_element?(home, "##{id}")
      assert has_element?(home, "a[href='#{href}']")
    end

    refute has_element?(home, "#nav-vendor")
    refute has_element?(home, "#nav-sign-out")
    refute has_element?(home, "#cart-link")
    refute has_element?(home, "#nav-orders")

    {:ok, privacy, privacy_html} = live(conn, ~p"/privacy")
    assert has_element?(privacy, "#privacy")
    assert privacy_html =~ "Card numbers are entered on Stripe"

    {:ok, terms, terms_html} = live(conn, ~p"/terms")
    assert has_element?(terms, "#terms")
    assert terms_html =~ "shipping fee"
  end

  test "the header shows buyer pages after sign-in and the dashboard only for a vendor", %{
    conn: conn
  } do
    buyer = register_user(%{display_name: "Ada"})
    {:ok, buyer_home, _} = live(log_in(conn, buyer), ~p"/")

    assert has_element?(buyer_home, "#cart-link")
    assert has_element?(buyer_home, "#nav-orders")
    assert has_element?(buyer_home, "#inbox-link")
    assert has_element?(buyer_home, "#nav-account")
    assert has_element?(buyer_home, "#nav-sign-out")
    refute has_element?(buyer_home, "#nav-sign-in")
    refute has_element?(buyer_home, "#nav-register")
    refute has_element?(buyer_home, "#nav-vendor")
    refute has_element?(buyer_home, "#nav-shop")
    assert has_element?(buyer_home, "#open-shop")

    vendor = register_user(%{role: :vendor, display_name: "Volt"})
    {:ok, vendor_home, _} = live(log_in(conn, vendor), ~p"/")

    assert has_element?(vendor_home, "#nav-vendor")
    assert has_element?(vendor_home, "#nav-shop")
    assert has_element?(vendor_home, "#nav-vendor-orders")
    assert has_element?(vendor_home, "#inbox-link")
    assert has_element?(vendor_home, "#nav-account")
    assert has_element?(vendor_home, "#nav-sign-out")
    refute has_element?(vendor_home, "#nav-sign-in")
    refute has_element?(vendor_home, "#cart-link")
    refute has_element?(vendor_home, "#nav-orders")
  end

  test "a customer can open the vendor dashboard from the home page", %{conn: conn} do
    buyer = register_user(%{display_name: "Ada Shop"})
    {:ok, view, _} = live(log_in(conn, buyer), ~p"/")

    assert {:error, {:redirect, %{to: "/vendor"}}} =
             view |> element("#open-shop") |> render_click()

    {:ok, user} = Ash.get(OdinMarket.Accounts.User, buyer.id, authorize?: false)
    assert user.role == :vendor

    {:ok, dashboard, html} = live(log_in(conn, user), ~p"/vendor")
    assert html =~ "Ada Shop"
    assert has_element?(dashboard, "#listing-form")
  end

  test "phoenix sends guests to sign in and keeps customers out of the shop", %{conn: conn} do
    for path <- [~p"/cart", ~p"/orders", ~p"/account", ~p"/inbox", ~p"/vendor"] do
      guest = get(conn, path)
      assert redirected_to(guest) == "/sign-in"
      assert get_session(guest, :return_to) == path
    end

    buyer = register_user()
    buyer_conn = log_in(conn, buyer)
    assert {:ok, _cart, _} = live(buyer_conn, ~p"/cart")
    assert {:error, {:redirect, %{to: "/"}}} = live(buyer_conn, ~p"/vendor")
    assert {:error, {:redirect, %{to: "/"}}} = live(buyer_conn, ~p"/vendor/shop")

    vendor = register_user(%{role: :vendor, display_name: "Paused"})
    profile = OdinMarket.Accounts.profile_for(vendor)

    {:ok, _} =
      Ash.update(profile, %{status: :suspended}, action: :set_status, authorize?: false)

    assert {:error, {:redirect, %{to: "/"}}} = live(log_in(conn, vendor), ~p"/vendor")
  end

  test "a vendor updates stock from the dashboard", %{conn: conn} do
    vendor = register_user(%{role: :vendor, display_name: "Stock Shop"})
    category = ensure_category("Power", "power-stock-#{System.unique_integer([:positive])}")

    listing =
      create_listing(vendor, %{
        category_id: category.id,
        title: "Stock board",
        qty_available: 4,
        price_cents: 900,
        shipping_cents: 200
      })

    conn = log_in(conn, vendor)
    {:ok, view, html} = live(conn, ~p"/vendor")
    assert html =~ "Stock board"
    assert has_element?(view, "#listing-form")
    assert has_element?(view, "#edit-listing-#{listing.id}")
    assert has_element?(view, "#delete-listing-#{listing.id}")
    assert has_element?(view, "#stock-form-#{listing.id}")

    view
    |> form("#stock-form-#{listing.id}", %{"stock" => %{"qty" => "0"}})
    |> render_submit(%{"id" => listing.id})

    assert render(view) =~ "Stock updated"
    {:ok, saved} = OdinMarket.Catalog.get_owned(listing.id, vendor)
    assert saved.qty_available == 0
    assert saved.status == :sold_out

    view |> element("#delete-listing-#{listing.id}") |> render_click()
    assert render(view) =~ "Listing archived"
    {:ok, archived} = OdinMarket.Catalog.get_owned(listing.id, vendor)
    assert archived.status == :archived
  end

  test "a signed-in account can search and sees saved cards", %{conn: conn} do
    buyer = register_user(%{display_name: "Ada"})
    conn = log_in(conn, buyer)
    {:ok, view, _html} = live(conn, ~p"/account")

    assert has_element?(view, "#account-search")
    assert has_element?(view, "#account-links")
    assert has_element?(view, "#cards-empty")
    assert has_element?(view, "#save-card")
    assert has_element?(view, "#delete-account")
    assert has_element?(view, "#delete-account-form")
  end

  test "deleting an account signs the user out", %{conn: conn} do
    buyer = register_user(%{display_name: "Gone"})
    conn = log_in(conn, buyer)
    {:ok, view, _html} = live(conn, ~p"/account")

    assert {:error, {:redirect, %{to: "/sign-out"}}} =
             view
             |> form("#delete-account-form", %{
               "account" => %{"current_password" => "password123456"}
             })
             |> render_submit()
  end
end
