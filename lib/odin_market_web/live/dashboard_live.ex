defmodule OdinMarketWeb.DashboardLive do
  use OdinMarketWeb, :live_view

  alias OdinMarket.Accounts
  alias OdinMarket.Catalog
  alias OdinMarket.Orders

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    profile = Accounts.profile_for(user)

    listings =
      if profile do
        Catalog.vendor_listings(profile, user)
      else
        []
      end

    {:ok,
     socket
     |> assign(:page_title, "Dashboard")
     |> assign(:profile, profile)
     |> assign(:vendor?, Accounts.vendor?(user))
     |> assign(:listings, listings)
     |> assign(:orders, user |> Orders.list_for_buyer() |> Enum.take(5))}
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
      <.flex direction="col" gap="gap-10" class="w-full">
        <.flex direction="col" gap="small">
          <h1>Dashboard</h1>
          <p>{@current_user.display_name} · @{to_string(@current_user.username)}</p>
        </.flex>

        <.dashboard_links vendor?={@vendor?} current={:overview} />

        <.card variant="base" color="natural" rounded="small" padding="medium" space="medium">
          <.form_wrapper
            id="account-search"
            for={%{}}
            action={~p"/browse"}
            method="get"
            variant="transparent"
            space="small"
            rounded="small"
          >
            <.flex align="end" gap="small" class="w-full">
              <.text_field
                id="account-q"
                name="q"
                value=""
                label="Search parts"
                placeholder="Title or description"
                size="medium"
                rounded="small"
                color="natural"
                class="min-w-0 flex-1"
              />
              <.button type="submit" variant="default" color="dark" size="medium" rounded="small">
                Search
              </.button>
            </.flex>
          </.form_wrapper>
        </.card>

        <%= if @vendor? do %>
          <.flex direction="col" gap="medium">
            <h2>Shop</h2>
            <p>{@profile.shop_name} is on the market.</p>
            <.grid cols="grid-cols-1 sm:grid-cols-3" gap="medium" class="w-full">
              <.card variant="base" color="natural" rounded="small" padding="medium" space="small">
                <p>Listings</p>
                <h3>{length(@listings)}</h3>
              </.card>
              <.card variant="base" color="natural" rounded="small" padding="medium" space="small">
                <p>Active</p>
                <h3>{Enum.count(@listings, &(&1.status == :active))}</h3>
              </.card>
              <.card variant="base" color="natural" rounded="small" padding="medium" space="small">
                <p>In stock</p>
                <h3>
                  {Enum.count(@listings, &(&1.status == :active and (&1.qty_available || 0) > 0))}
                </h3>
              </.card>
            </.grid>
          </.flex>
        <% else %>
          <.card
            id="vendor-upgrade"
            variant="base"
            color="natural"
            rounded="small"
            padding="medium"
            space="medium"
          >
            <h2>Vendor</h2>
            <p>
              <%= if @profile do %>
                The shop is paused. History stays. Subscribe again to list embedded hardware.
              <% else %>
                Vendor is a subscription for selling embedded electronics. A$25 a month, A$70 every 3 months, or A$240 a year.
              <% end %>
            </p>
            <.button_link
              id="become-vendor"
              navigate={~p"/vendor/pricing"}
              variant="default"
              color="dark"
              size="medium"
              rounded="small"
              class="self-start"
            >
              {if(@profile, do: "Renew Vendor", else: "Become a vendor")}
            </.button_link>
          </.card>
        <% end %>

        <.flex id="settings-history" direction="col" gap="medium">
          <h2>Recent purchases</h2>
          <.alert :if={@orders == []} id="history-empty" kind={:natural} title="No orders yet">
            When you buy a part, it shows up here.
          </.alert>
          <.table
            :if={@orders != []}
            id="account-history"
            rows={@orders}
            variant="base"
            color="natural"
            rounded="small"
            padding="medium"
          >
            <:col :let={order} label="Listing">{order.listing && order.listing.title}</:col>
            <:col :let={order} label="Total">{money(charge_cents(order))}</:col>
            <:col :let={order} label="Status">{status_label(order.status)}</:col>
            <:col :let={order} label="">
              <.button_link
                navigate={~p"/dashboard/orders/#{order.id}"}
                variant="outline"
                color="natural"
                size="small"
                rounded="small"
              >
                View
              </.button_link>
            </:col>
          </.table>
        </.flex>
      </.flex>
    </.market_layout>
    """
  end
end
