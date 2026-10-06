defmodule OdinMarketWeb.PageLiveTest do
  use OdinMarketWeb.ConnCase, async: true

  test "the empty homepage, privacy, and terms are public", %{conn: conn} do
    {:ok, home, home_html} = live(conn, ~p"/")
    refute has_element?(home, "#home-search")
    assert has_element?(home, "#home-hero")
    assert has_element?(home, "#hero-browse")
    assert has_element?(home, "#hero-register")
    refute has_element?(home, "#hero-sell")
    refute has_element?(home, "#hero-vendor")
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
          {"nav-forum", "/forum"},
          {"nav-sign-in", "/sign-in"},
          {"nav-register", "/register"},
          {"footer-privacy", "/privacy"},
          {"footer-terms", "/terms"}
        ] do
      assert has_element?(home, "##{id}")
      assert has_element?(home, "a[href='#{href}']")
    end

    refute has_element?(home, "#nav-dashboard")
    refute has_element?(home, "#nav-open-dashboard")
    refute has_element?(home, "#hero-dashboard")
    refute has_element?(home, "#nav-sign-out")
    refute has_element?(home, "#cart-link")
    refute has_element?(home, "#nav-orders")

    {:ok, privacy, privacy_html} = live(conn, ~p"/privacy")
    assert has_element?(privacy, "#privacy")
    assert privacy_html =~ "Card numbers are entered on Stripe"

    {:ok, terms, terms_html} = live(conn, ~p"/terms")
    assert has_element?(terms, "#terms")
    assert terms_html =~ "shipping fee"
    assert terms_html =~ "no refund"
    assert has_element?(terms, "#terms-revocation")
  end

  test "the header shows a dashboard for every member and shop links for a vendor", %{
    conn: conn
  } do
    buyer = register_user(%{display_name: "Ada"})
    {:ok, buyer_home, _} = live(log_in(conn, buyer), ~p"/")

    assert has_element?(buyer_home, "#cart-link")
    assert has_element?(buyer_home, "#nav-orders")
    assert has_element?(buyer_home, "#nav-dashboard")
    assert has_element?(buyer_home, "#inbox-link")
    assert has_element?(buyer_home, "#nav-account")
    assert has_element?(buyer_home, "#nav-sign-out")
    assert has_element?(buyer_home, "#hero-vendor")
    refute has_element?(buyer_home, "#nav-sign-in")
    refute has_element?(buyer_home, "#nav-register")
    refute has_element?(buyer_home, "#nav-shop")
    refute has_element?(buyer_home, "#nav-vendor-orders")
    refute has_element?(buyer_home, "#hero-dashboard")
    refute has_element?(buyer_home, "#open-shop")

    vendor = register_user(%{role: :vendor, display_name: "Volt"})
    {:ok, vendor_home, _} = live(log_in(conn, vendor), ~p"/")

    assert has_element?(vendor_home, "#nav-dashboard")
    assert has_element?(vendor_home, "#cart-link")
    assert has_element?(vendor_home, "#nav-orders")
    assert has_element?(vendor_home, "#nav-shop")
    assert has_element?(vendor_home, "#nav-vendor-orders")
    assert has_element?(vendor_home, "#inbox-link")
    assert has_element?(vendor_home, "#nav-account")
    assert has_element?(vendor_home, "#nav-sign-out")
    assert has_element?(vendor_home, "#hero-dashboard")
    refute has_element?(vendor_home, "#nav-sign-in")
    refute has_element?(vendor_home, "#hero-vendor")
  end

  test "a member is offered vendor pricing instead of a free shop", %{conn: conn} do
    buyer = register_user(%{display_name: "Ada Shop"})
    conn = log_in(conn, buyer)
    {:ok, home, _} = live(conn, ~p"/")
    assert has_element?(home, "a[href='/vendor/pricing']")

    {:ok, pricing, html} = live(conn, ~p"/vendor/pricing")
    assert has_element?(pricing, "#plan-month")
    assert has_element?(pricing, "#plan-quarter")
    assert has_element?(pricing, "#plan-year")
    assert has_element?(pricing, "#subscribe-month")
    assert html =~ "A$25"
    assert html =~ "A$70"
    assert html =~ "A$240"

    {:ok, user} = Ash.get(OdinMarket.Accounts.User, buyer.id, authorize?: false)
    assert user.role == :member
    refute user.selling
  end

  test "phoenix sends guests to sign in and keeps members out of a shop", %{conn: conn} do
    for path <- [~p"/cart", ~p"/orders", ~p"/account", ~p"/inbox", ~p"/vendor", ~p"/dashboard"] do
      guest = get(conn, path)
      assert redirected_to(guest) == "/sign-in"
      assert get_session(guest, :return_to) == path
    end

    cart = get(conn, ~p"/cart")
    {:ok, sign_in, sign_in_html} = live(cart, ~p"/sign-in")
    assert has_element?(sign_in, "#auth-flash")
    assert sign_in_html =~ "Sign in to continue."
    assert sign_in_html =~ "bg-neutral-900"

    buyer = register_user()
    buyer_conn = log_in(conn, buyer)
    assert {:ok, _cart, _} = live(buyer_conn, ~p"/cart")
    assert {:error, {:redirect, %{to: "/dashboard"}}} = live(buyer_conn, ~p"/vendor")

    assert {:error, {:redirect, %{to: "/vendor/pricing"}}} =
             live(buyer_conn, ~p"/dashboard/shop")

    vendor = register_user(%{role: :vendor, display_name: "Paused"})
    profile = OdinMarket.Accounts.profile_for(vendor)

    {:ok, _} =
      Ash.update(profile, %{status: :suspended}, action: :set_status, authorize?: false)

    assert {:error, {:redirect, %{to: "/vendor/pricing"}}} =
             live(log_in(conn, vendor), ~p"/dashboard/shop")
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
    {:ok, view, html} = live(conn, ~p"/dashboard/listings")
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
    {:ok, dashboard, _html} = live(conn, ~p"/dashboard")
    assert has_element?(dashboard, "#account-search")
    assert has_element?(dashboard, "#account-links")

    {:ok, billing, _html} = live(conn, ~p"/dashboard/billing")
    assert has_element?(billing, "#cards-empty")
    assert has_element?(billing, "#save-card")

    {:ok, view, _html} = live(conn, ~p"/dashboard/settings")
    assert has_element?(view, "#delete-account")
    assert has_element?(view, "#delete-account-form")
  end

  test "deleting an account signs the user out", %{conn: conn} do
    buyer = register_user(%{display_name: "Gone"})
    conn = log_in(conn, buyer)
    {:ok, view, _html} = live(conn, ~p"/dashboard/settings")

    assert {:error, {:redirect, %{to: "/sign-out"}}} =
             view
             |> form("#delete-account-form", %{
               "account" => %{"current_password" => "password123456"}
             })
             |> render_submit()
  end
end
