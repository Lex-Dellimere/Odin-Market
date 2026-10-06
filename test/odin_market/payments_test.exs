defmodule OdinMarket.PaymentsTest do
  use OdinMarket.DataCase, async: false

  require Ash.Query

  alias OdinMarket.Accounts
  alias OdinMarket.Catalog
  alias OdinMarket.Orders
  alias OdinMarket.Orders.Order
  alias OdinMarket.Payments

  @secret "whsec_test"

  setup do
    previous = Application.get_env(:stripity_stripe, :webhook_secret)
    Application.put_env(:stripity_stripe, :webhook_secret, @secret)

    on_exit(fn ->
      if previous do
        Application.put_env(:stripity_stripe, :webhook_secret, previous)
      else
        Application.delete_env(:stripity_stripe, :webhook_secret)
      end
    end)

    vendor = register_user(%{role: :vendor, display_name: "Shop"})
    buyer = register_user(%{display_name: "Buyer"})
    category = ensure_category("MCUs", "mcu-#{System.unique_integer([:positive])}")

    listing =
      create_listing(vendor, %{
        category_id: category.id,
        title: "Module",
        qty_available: 3,
        price_cents: 900
      })

    {:ok, order} = Orders.open(buyer, listing.id, 1, nil)

    %{listing: listing, order: order, buyer: buyer, vendor: vendor, category: category}
  end

  test "a signed checkout event decrements stock once", %{listing: listing, order: order} do
    payload = checkout_event(order.id)
    assert :ok = Payments.handle_webhook(payload, sign(payload))
    assert :ok = Payments.handle_webhook(payload, sign(payload))

    assert {:ok, %{qty_available: 2}} = Catalog.get_listing(listing.id)
    assert {:ok, %Order{status: :paid}} = Ash.get(Order, order.id, authorize?: false)
  end

  test "a bad signature is rejected", %{order: order} do
    payload = checkout_event(order.id)
    assert {:error, :bad_signature} = Payments.handle_webhook(payload, "t=1,v1=deadbeef")
    assert {:ok, %{qty_available: 3}} = Catalog.get_listing(order.listing_id)
  end

  test "an oversold payment cancels the order", %{listing: listing, order: order} do
    qty = listing.qty_available

    result =
      OdinMarket.Catalog.Listing
      |> Ash.Query.filter(id == ^listing.id and qty_available >= ^qty)
      |> Ash.bulk_update(:decrement_stock, %{qty: qty},
        strategy: [:atomic],
        authorize?: false,
        authorize_query?: false,
        return_records?: true,
        return_errors?: true
      )

    assert %Ash.BulkResult{status: :success, records: [_]} = result

    payload = checkout_event(order.id)
    assert :ok = Payments.handle_webhook(payload, sign(payload))

    assert {:ok, %Order{status: :cancelled, note: note}} =
             Ash.get(Order, order.id, authorize?: false)

    assert note =~ "out of stock"
    assert {:ok, %{qty_available: 0}} = Catalog.get_listing(listing.id)
  end

  test "one checkout event settles every order id", %{
    listing: listing,
    order: order,
    buyer: buyer,
    vendor: vendor,
    category: category
  } do
    other =
      create_listing(vendor, %{
        category_id: category.id,
        title: "Second module",
        qty_available: 4,
        price_cents: 400
      })

    {:ok, second} = Orders.open(buyer, other.id, 2, nil)

    payload =
      checkout_event(order.id, "checkout.session.completed", %{
        "order_ids" => "#{order.id},#{second.id}"
      })

    assert :ok = Payments.handle_webhook(payload, sign(payload))
    assert :ok = Payments.handle_webhook(payload, sign(payload))

    assert {:ok, %Order{status: :paid}} = Ash.get(Order, order.id, authorize?: false)
    assert {:ok, %Order{status: :paid}} = Ash.get(Order, second.id, authorize?: false)
    assert {:ok, %{qty_available: 2}} = Catalog.get_listing(listing.id)
    assert {:ok, %{qty_available: 2}} = Catalog.get_listing(other.id)
  end

  test "a setup checkout saves the card brand and last four digits", %{buyer: buyer} do
    payload =
      Jason.encode!(%{
        id: "evt_#{System.unique_integer([:positive])}",
        object: "event",
        type: "checkout.session.completed",
        created: System.system_time(:second),
        livemode: false,
        pending_webhooks: 1,
        data: %{
          object: %{
            id: "cs_setup_#{System.unique_integer([:positive])}",
            object: "checkout.session",
            mode: "setup",
            metadata: %{user_id: buyer.id, purpose: "save_card"},
            setup_intent: %{
              id: "seti_visa_4242",
              object: "setup_intent",
              payment_method: %{
                id: "pm_visa_4242",
                object: "payment_method",
                type: "card",
                card: %{brand: "visa", last4: "4242", exp_month: 12, exp_year: 2030}
              }
            }
          }
        }
      })

    assert :ok = Payments.handle_webhook(payload, sign(payload))
    assert :ok = Payments.handle_webhook(payload, sign(payload))

    assert [%{brand: "visa", last4: "4242"}] = Accounts.list_cards(buyer)
  end

  test "unknown events and unknown orders are acknowledged", %{order: order} do
    unknown_event = checkout_event(order.id, "charge.refunded")
    assert :ok = Payments.handle_webhook(unknown_event, sign(unknown_event))

    missing = checkout_event(Ecto.UUID.generate())
    assert :ok = Payments.handle_webhook(missing, sign(missing))

    assert {:ok, %Order{status: :pending_payment}} = Ash.get(Order, order.id, authorize?: false)
    assert {:ok, %{qty_available: 3}} = Catalog.get_listing(order.listing_id)
  end

  defp checkout_event(order_id, type \\ "checkout.session.completed", metadata \\ %{}) do
    Jason.encode!(%{
      id: "evt_#{System.unique_integer([:positive])}",
      object: "event",
      type: type,
      created: System.system_time(:second),
      livemode: false,
      pending_webhooks: 1,
      data: %{
        object: %{
          id: "cs_test_#{System.unique_integer([:positive])}",
          object: "checkout.session",
          metadata: Map.merge(%{"order_id" => order_id}, metadata)
        }
      }
    })
  end

  defp sign(payload) do
    timestamp = System.system_time(:second)
    digest = :crypto.mac(:hmac, :sha256, @secret, "#{timestamp}.#{payload}")
    "t=#{timestamp},v1=#{Base.encode16(digest, case: :lower)}"
  end
end
