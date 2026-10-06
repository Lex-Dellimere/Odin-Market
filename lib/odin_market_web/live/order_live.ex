defmodule OdinMarketWeb.OrderLive do
  use OdinMarketWeb, :live_view

  alias OdinMarket.Orders

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(page_title: "Orders", orders: [], order: nil, missing: false)
     |> assign(:vendor?, OdinMarket.Accounts.vendor?(socket.assigns.current_user))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    user = socket.assigns.current_user

    orders = Orders.list_for_buyer(user)

    socket =
      socket
      |> assign(:orders, orders)
      |> assign(:open_orders, Enum.reject(orders, &history_order?/1))
      |> assign(:past_orders, Enum.filter(orders, &history_order?/1))
      |> assign(:missing, false)

    socket =
      if socket.assigns.live_action == :show do
        case Orders.get_order(user, params["id"]) do
          {:ok, order} ->
            socket
            |> assign(:order, order)
            |> assign(:page_title, "Order")

          _ ->
            assign(socket, order: nil, missing: true, page_title: "Not found")
        end
      else
        assign(socket, :order, nil)
      end

    {:noreply, socket}
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
        <h1>{if @live_action == :show, do: "Order", else: "Orders"}</h1>
        <.dashboard_links vendor?={@vendor?} current={:orders} />
        <.alert
          :if={@orders == [] and @live_action == :index}
          id="orders-empty"
          kind={:natural}
          title="No orders"
        >
          When you buy a part, it shows up here.
        </.alert>
        <.flex
          :if={@live_action == :index and @orders != []}
          id="open-orders"
          direction="col"
          gap="medium"
        >
          <h2>Open</h2>
          <.alert :if={@open_orders == [] and @orders != []} kind={:natural} title="Nothing open">
            Finished orders are in the history below.
          </.alert>
          <.order_table :if={@open_orders != []} id="orders" orders={@open_orders} />
        </.flex>
        <.flex :if={@live_action == :index} id="order-history" direction="col" gap="medium">
          <h2 :if={@orders != []}>History</h2>
          <.alert :if={@past_orders == [] and @orders != []} kind={:natural} title="No history yet">
            Completed, cancelled, and refunded orders land here.
          </.alert>
          <.order_table :if={@past_orders != []} id="history" orders={@past_orders} />
        </.flex>

        <.alert :if={@missing} id="not-found" kind={:danger} title="Not found">
          That order is not available.
        </.alert>

        <.card
          :if={@order}
          id="order"
          variant="base"
          color="natural"
          rounded="small"
          padding="medium"
          space="medium"
        >
          <.flex direction="col" gap="medium">
            <h2>{@order.listing && @order.listing.title}</h2>
            <p>{status_label(@order.status)}</p>
            <p>{money(@order.unit_price_cents)} × {@order.qty}</p>
            <p>{shipping_label(@order)}</p>
            <p>Total {money(charge_cents(@order))}</p>
            <p :if={@order.notes}>{@order.notes}</p>
            <p :if={@order.note}>{@order.note}</p>
            <.shipping_address record={@order} />
            <p :if={@order.status == :pending_payment}>Waiting for payment confirmation.</p>
          </.flex>
        </.card>
      </.flex>
    </.market_layout>
    """
  end

  attr :id, :string, required: true
  attr :orders, :list, required: true

  defp order_table(assigns) do
    ~H"""
    <.table
      id={@id}
      rows={@orders}
      variant="base"
      color="natural"
      rounded="small"
      padding="medium"
    >
      <:col :let={order} label="Listing">{order.listing && order.listing.title}</:col>
      <:col :let={order} label="Qty">{order.qty}</:col>
      <:col :let={order} label="Total">{money(charge_cents(order))}</:col>
      <:col :let={order} label="Status">{status_label(order.status)}</:col>
      <:col :let={order} label="">
        <.button_link
          navigate={~p"/dashboard/orders/#{order.id}"}
          variant="default"
          color="dark"
          size="medium"
          rounded="small"
        >
          View
        </.button_link>
      </:col>
    </.table>
    """
  end

  defp history_order?(order), do: order.status in [:complete, :cancelled, :refunded]
end
