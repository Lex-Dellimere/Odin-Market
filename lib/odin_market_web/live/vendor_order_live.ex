defmodule OdinMarketWeb.VendorOrderLive do
  use OdinMarketWeb, :live_view

  alias OdinMarket.Orders

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Sales", orders: [], order: nil, missing: false)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    orders = Orders.list_for_vendor(socket.assigns.vendor_profile, socket.assigns.current_user)
    socket = assign(socket, :orders, orders)

    socket =
      if socket.assigns.live_action == :show do
        load_order(socket, params["id"])
      else
        assign(socket, :order, nil)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("advance", _params, socket) do
    order = socket.assigns.order
    next = Orders.next_status(order.status)

    case Orders.advance(order, socket.assigns.current_user, next) do
      {:ok, updated} ->
        {:noreply,
         assign(socket, :order, Ash.load!(updated, [:listing, :buyer], authorize?: false))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "That status can't be set from here.")}
    end
  end

  defp load_order(socket, id) do
    case Orders.get_order(socket.assigns.current_user, id) do
      {:ok, order} ->
        if order.vendor_id == socket.assigns.vendor_profile.id do
          socket
          |> assign(:order, order)
          |> assign(:missing, false)
          |> assign(:page_title, "Order")
        else
          assign(socket, order: nil, missing: true)
        end

      _ ->
        assign(socket, order: nil, missing: true, page_title: "Not found")
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.market_layout
      flash={@flash}
      current_scope={@current_scope}
      nav_categories={@nav_categories}
      unread_count={@unread_count}
      nav_query={@nav_query}
    >
      <.flex direction="col" gap="medium" class="w-full">
        <h1>Sales</h1>
        <.dashboard_links vendor?={true} current={:sales} />
        <.flex :if={@live_action == :index} direction="col" gap="medium">
          <.alert :if={@orders == []} id="vendor-orders-empty" kind={:natural} title="No paid orders">
            Paid orders show up here. Unpaid checkouts stay with the buyer.
          </.alert>
          <.table
            :if={@orders != []}
            id="vendor-orders"
            rows={@orders}
            variant="base"
            color="natural"
            rounded="small"
            padding="medium"
          >
            <:col :let={order} label="Listing">{order.listing && order.listing.title}</:col>
            <:col :let={order} label="Buyer">{order.buyer && order.buyer.display_name}</:col>
            <:col :let={order} label="Status">{status_label(order.status)}</:col>
            <:col :let={order} label="">
              <.button_link
                navigate={~p"/dashboard/sales/#{order.id}"}
                variant="default"
                color="dark"
                size="medium"
                rounded="small"
              >
                Open
              </.button_link>
            </:col>
          </.table>
        </.flex>

        <.alert :if={@missing} id="not-found" kind={:danger} title="Not found">
          That order is not in your shop.
        </.alert>

        <.card
          :if={@order}
          id="vendor-order"
          variant="base"
          color="natural"
          rounded="small"
          padding="medium"
          space="medium"
        >
          <.flex direction="col" gap="medium">
            <h2>{@order.listing && @order.listing.title}</h2>
            <p>Buyer: {@order.buyer && @order.buyer.display_name}</p>
            <p>Status: {status_label(@order.status)}</p>
            <p>{money(@order.unit_price_cents)} × {@order.qty}</p>
            <p>{shipping_label(@order)}</p>
            <p>Total {money(charge_cents(@order))}</p>
            <p :if={@order.notes} class="whitespace-pre-line">{@order.notes}</p>
            <p :if={@order.note}>{@order.note}</p>
            <.shipping_address record={@order} />
            <.button
              :if={Orders.next_status(@order.status)}
              id="advance-order"
              type="button"
              variant="default"
              color="dark"
              size="medium"
              rounded="small"
              phx-click="advance"
            >
              Mark {status_label(Orders.next_status(@order.status))}
            </.button>
          </.flex>
        </.card>
      </.flex>
    </.market_layout>
    """
  end
end
