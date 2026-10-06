defmodule OdinMarket.OrdersTest do
  use OdinMarket.DataCase, async: true

  alias OdinMarket.Checkout
  alias OdinMarket.Orders
  alias OdinMarket.Orders.Order

  setup do
    vendor = register_user(%{role: :vendor, display_name: "Volt"})
    buyer = register_user(%{display_name: "Ada"})
    category = ensure_category("Power", "power-#{System.unique_integer([:positive])}")

    listing =
      create_listing(vendor, %{
        category_id: category.id,
        title: "Buck module",
        qty_available: 2,
        price_cents: 500
      })

    %{vendor: vendor, buyer: buyer, category: category, listing: listing}
  end

  test "opening an order rejects the vendor's own listing", %{vendor: vendor, listing: listing} do
    assert {:error, :own_listing} = Orders.open(vendor, listing.id, 1, nil)
    assert {:error, :own_listing} = Checkout.start(vendor, listing.id, 1, nil)
  end

  test "opening an order rejects a draft listing", %{
    buyer: buyer,
    vendor: vendor,
    category: category
  } do
    draft =
      create_listing(vendor, %{category_id: category.id, status: :draft, title: "Draft psu"})

    assert {:error, :inactive} = Orders.open(buyer, draft.id, 1, nil)
    assert {:error, :inactive} = Checkout.start(buyer, draft.id, 1, nil)
  end

  test "opening an order rejects a quantity above stock", %{buyer: buyer, listing: listing} do
    assert {:error, :above_stock} = Orders.open(buyer, listing.id, 9, nil)
    assert {:error, :above_stock} = Checkout.start(buyer, listing.id, "9", nil)
  end

  test "a buyer cannot mark an order paid", %{buyer: buyer, listing: listing} do
    assert {:ok, order} = Orders.open(buyer, listing.id, 1, nil)

    assert {:error, %Ash.Error.Forbidden{}} =
             Ash.update(order, %{}, action: :mark_paid, actor: buyer)

    assert {:ok, %Order{status: :pending_payment}} =
             Ash.get(Order, order.id, authorize?: false)
  end
end
