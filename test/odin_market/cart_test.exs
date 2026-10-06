defmodule OdinMarket.CartTest do
  use OdinMarket.DataCase, async: true

  alias OdinMarket.Accounts
  alias OdinMarket.Checkout
  alias OdinMarket.Orders
  alias OdinMarket.Orders.Order

  setup do
    vendor = register_user(%{role: :vendor, display_name: "Volt"})
    buyer = register_user(%{display_name: "Ada"})
    category = ensure_category("Power", "power-cart-#{System.unique_integer([:positive])}")

    listing =
      create_listing(vendor, %{
        category_id: category.id,
        title: "Buck module",
        qty_available: 4,
        price_cents: 500
      })

    %{vendor: vendor, buyer: buyer, category: category, listing: listing}
  end

  test "adding the same listing updates that cart line", %{buyer: buyer, listing: listing} do
    assert {:ok, _} = Orders.add_to_cart(buyer, listing.id, 1, nil)
    assert {:ok, _} = Orders.add_to_cart(buyer, listing.id, "3", "rush")

    assert [item] = Orders.list_cart(buyer)
    assert item.qty == 3
    assert item.notes == "rush"
    assert item.listing_id == listing.id
    assert Orders.cart_count(buyer) == 1
  end

  test "a vendor cannot add their own listing", %{vendor: vendor, listing: listing} do
    assert {:error, :own_listing} = Orders.add_to_cart(vendor, listing.id, 1, nil)
    assert Orders.list_cart(vendor) == []
  end

  test "removing a line empties the cart", %{buyer: buyer, listing: listing} do
    assert {:ok, item} = Orders.add_to_cart(buyer, listing.id, 1, nil)
    assert :ok = Orders.remove_cart_line(item, buyer)
    assert Orders.list_cart(buyer) == []
    assert Orders.cart_count(buyer) == 0
  end

  test "a custom line stays at quantity 1", %{buyer: buyer, vendor: vendor, category: category} do
    custom =
      create_listing(vendor, %{
        category_id: category.id,
        title: "Custom cable",
        kind: :custom,
        lead_days: 5,
        qty_available: nil,
        price_cents: 2_000
      })

    assert {:ok, item} = Orders.add_to_cart(buyer, custom.id, 4, "shielded")
    assert item.qty == 1
    assert item.notes == "shielded"
  end

  test "save profile stores the shipping address", %{buyer: buyer} do
    assert {:ok, buyer} = Accounts.save_profile(buyer, address_params())
    assert buyer.display_name == "Ada Lovelace"
    assert buyer.ship_line1 == "1 Bench Street"
    assert buyer.ship_city == "Oslo"
    assert buyer.ship_country == "Norway"
    assert buyer.ship_line2 == nil
  end

  test "checkout refuses an empty address and copies a complete one", %{
    buyer: buyer,
    listing: listing
  } do
    assert {:ok, _} = Orders.add_to_cart(buyer, listing.id, 1, nil)
    assert {:error, :address_required} = Checkout.start_cart(buyer)
    assert {:ok, nil} = Orders.find_pending(buyer, listing.id)
    assert Orders.list_for_buyer(buyer) == []

    assert {:ok, buyer} = Accounts.save_profile(buyer, address_params())

    case Checkout.start_cart(buyer) do
      {:ok, url} -> assert is_binary(url)
      {:error, :not_configured} -> :ok
      {:error, %{}} -> :ok
    end

    assert {:ok, %Order{} = order} = Orders.find_pending(buyer, listing.id)
    assert order.ship_name == "Ada Lovelace"
    assert order.ship_line1 == "1 Bench Street"
    assert order.ship_city == "Oslo"
    assert order.ship_country == "Norway"
    assert order.status == :pending_payment

    assert {:ok, buyer} =
             Accounts.save_profile(buyer, %{
               "display_name" => "Ada Lovelace",
               "ship_city" => "Bergen"
             })

    assert {:ok, %Order{ship_city: "Oslo"}} = Ash.get(Order, order.id, authorize?: false)
    assert buyer.ship_city == "Bergen"
  end

  test "a shop website must be http or https", %{vendor: vendor} do
    profile = Accounts.profile_for(vendor)

    assert {:error, %Ash.Error.Invalid{}} =
             Ash.update(profile, %{website: "javascript:alert(1)"},
               action: :update_shop,
               actor: vendor
             )

    assert {:error, %Ash.Error.Invalid{}} =
             Ash.update(profile, %{website: "example.com"}, action: :update_shop, actor: vendor)

    assert {:ok, profile} =
             Ash.update(profile, %{website: " https://volt.example "},
               action: :update_shop,
               actor: vendor
             )

    assert profile.website == "https://volt.example"

    assert {:ok, profile} =
             Ash.update(profile, %{website: "  "}, action: :update_shop, actor: vendor)

    assert profile.website == nil
  end

  defp address_params do
    %{
      "display_name" => "Ada Lovelace",
      "ship_name" => "Ada Lovelace",
      "ship_line1" => "1 Bench Street",
      "ship_line2" => "  ",
      "ship_city" => "Oslo",
      "ship_region" => "Oslo",
      "ship_postal_code" => "0150",
      "ship_country" => "Norway"
    }
  end
end
