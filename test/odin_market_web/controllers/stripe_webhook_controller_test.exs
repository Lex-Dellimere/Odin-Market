defmodule OdinMarketWeb.StripeWebhookControllerTest do
  use OdinMarketWeb.ConnCase, async: false

  alias OdinMarket.Catalog
  alias OdinMarket.Orders
  alias OdinMarket.Orders.Order

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

    :ok
  end

  test "a signed raw body marks the order paid", %{conn: conn} do
    vendor = register_user(%{role: :vendor, display_name: "Webhook Shop"})
    buyer = register_user(%{display_name: "Webhook Buyer"})
    category = ensure_category("Boards", "boards-wh-#{System.unique_integer([:positive])}")

    listing =
      create_listing(vendor, %{
        category_id: category.id,
        title: "Webhook board",
        qty_available: 4
      })

    {:ok, order} = Orders.open(buyer, listing.id, 1, nil)
    payload = checkout_event(order.id)

    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_header("stripe-signature", sign(payload))
      |> post(~p"/webhooks/stripe", payload)

    assert conn.status == 200
    assert {:ok, %{qty_available: 3}} = Catalog.get_listing(listing.id)
    assert {:ok, %Order{status: :paid}} = Ash.get(Order, order.id, authorize?: false)
  end

  test "a bad signature returns 400", %{conn: conn} do
    payload = checkout_event(Ecto.UUID.generate())

    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_header("stripe-signature", "t=1,v1=nope")
      |> post(~p"/webhooks/stripe", payload)

    assert conn.status == 400
  end

  defp checkout_event(order_id) do
    Jason.encode!(%{
      id: "evt_controller",
      object: "event",
      type: "checkout.session.completed",
      created: System.system_time(:second),
      livemode: false,
      data: %{
        object: %{
          id: "cs_controller",
          object: "checkout.session",
          metadata: %{order_id: order_id}
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
