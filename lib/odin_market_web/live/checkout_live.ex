defmodule OdinMarketWeb.CheckoutLive do
  use OdinMarketWeb, :live_view

  alias OdinMarket.Checkout
  alias OdinMarket.Errors
  alias OdinMarket.Orders

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Checkout", started: false, error: nil, order: nil)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, params) do
    socket = assign(socket, :page_title, "Checkout")

    if connected?(socket) and not socket.assigns.started do
      start_checkout(socket, params)
    else
      socket
    end
  end

  defp apply_action(socket, :success, params) do
    order =
      case Orders.get_order(socket.assigns.current_user, params["order_id"]) do
        {:ok, order} -> order
        _ -> nil
      end

    socket
    |> assign(:page_title, "Payment")
    |> assign(:order, order)
  end

  defp apply_action(socket, :cancel, params) do
    order =
      case Orders.get_order(socket.assigns.current_user, params["order_id"]) do
        {:ok, order} -> order
        _ -> nil
      end

    socket
    |> assign(:page_title, "Checkout cancelled")
    |> assign(:order, order)
  end

  defp start_checkout(socket, params) do
    socket = assign(socket, :started, true)

    case Checkout.start(
           socket.assigns.current_user,
           params["listing_id"],
           params["qty"] || "1",
           params["notes"]
         ) do
      {:ok, url} ->
        redirect(socket, external: url)

      {:error, reason} when is_atom(reason) ->
        assign(socket, :error, Errors.message(reason))

      {:error, _} ->
        assign(socket, :error, Errors.message(:not_configured))
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
      <div class="w-full">
        <.card
          :if={@live_action == :new}
          id="checkout"
          variant="base"
          color="natural"
          rounded="small"
          padding="medium"
          space="medium"
        >
          <.flex direction="col" gap="medium">
            <h1>Checkout</h1>
            <.alert :if={@error} id="checkout-error" kind={:danger} title="Can't start checkout">
              {@error}
            </.alert>
            <.flex :if={!@error} align="center" gap="medium">
              <.spinner color="natural" size="medium" />
              <p>Preparing a secure card payment.</p>
            </.flex>
          </.flex>
        </.card>

        <.card
          :if={@live_action == :success}
          id="checkout-success"
          variant="base"
          color="natural"
          rounded="small"
          padding="medium"
          space="medium"
        >
          <.flex direction="col" gap="medium">
            <h1>Payment submitted</h1>
            <p>
              We'll mark the order paid when Stripe confirms it. This page does not take payment itself.
            </p>
            <p :if={@order}>Current status: {status_label(@order.status)}</p>
            <.button_link
              navigate={~p"/dashboard/orders"}
              variant="default"
              color="dark"
              size="medium"
              rounded="small"
            >
              View orders
            </.button_link>
          </.flex>
        </.card>

        <.card
          :if={@live_action == :cancel}
          id="checkout-cancel"
          variant="base"
          color="natural"
          rounded="small"
          padding="medium"
          space="medium"
        >
          <.flex direction="col" gap="medium">
            <h1>Checkout cancelled</h1>
            <p>The order stays unpaid. You can start checkout again from the listing.</p>
            <.flex align="center" gap="medium">
              <.button_link
                :if={@order && @order.listing}
                navigate={~p"/l/#{@order.listing.slug}"}
                variant="outline"
                color="natural"
                size="medium"
                rounded="small"
              >
                Back to the listing
              </.button_link>
              <.button_link
                navigate={~p"/cart"}
                variant="default"
                color="dark"
                size="medium"
                rounded="small"
              >
                Back to the cart
              </.button_link>
            </.flex>
          </.flex>
        </.card>
      </div>
    </.market_layout>
    """
  end
end
