defmodule OdinMarket.MarketplaceTest do
  use OdinMarket.DataCase, async: true

  alias OdinMarket.Accounts
  alias OdinMarket.Catalog
  alias OdinMarket.Orders
  alias OdinMarket.Payments

  setup do
    vendor = register_user(%{role: :vendor, display_name: "Shop"})
    buyer = register_user(%{display_name: "Buyer"})
    category = ensure_category("Boards", "boards-mvp-#{System.unique_integer([:positive])}")

    listing =
      create_listing(vendor, %{
        category_id: category.id,
        title: "Sensor board",
        qty_available: 4,
        price_cents: 1_500,
        shipping_cents: 650
      })

    %{vendor: vendor, buyer: buyer, listing: listing}
  end

  test "an order copies the listing shipping fee", %{buyer: buyer, listing: listing} do
    assert {:ok, order} = Orders.open(buyer, listing.id, 2, nil)
    assert order.unit_price_cents == 1_500
    assert order.shipping_cents == 650
  end

  test "a vendor updates stock from the dashboard action", %{vendor: vendor, listing: listing} do
    assert {:ok, sold_out} = Catalog.set_stock(listing, "0", vendor)
    assert sold_out.qty_available == 0
    assert sold_out.status == :sold_out

    assert {:ok, restocked} = Catalog.set_stock(sold_out, 3, vendor)
    assert restocked.qty_available == 3
    assert restocked.status == :active
  end

  test "a buyer saves and removes a card without storing the card number", %{buyer: buyer} do
    previous = Application.get_env(:stripity_stripe, :api_key)
    Application.delete_env(:stripity_stripe, :api_key)

    on_exit(fn ->
      if previous, do: Application.put_env(:stripity_stripe, :api_key, previous)
    end)

    assert {:error, :not_configured} = Payments.start_card_setup(buyer)

    assert {:ok, card} =
             Accounts.save_card(buyer, %{
               stripe_payment_method_id: "pm_#{System.unique_integer([:positive])}",
               brand: "visa",
               last4: "4242",
               exp_month: 12,
               exp_year: 2030
             })

    assert card.last4 == "4242"
    assert [saved] = Accounts.list_cards(buyer)
    assert :ok = Accounts.remove_card(saved, buyer)
    assert Accounts.list_cards(buyer) == []
  end
end
