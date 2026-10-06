defmodule OdinMarketWeb.Layouts do
  @moduledoc """
  Application shell: navbar, page, and footer.
  """
  use OdinMarketWeb, :html

  embed_templates "layouts/*"

  attr :flash, :map, required: true
  attr :current_scope, :map, default: nil
  attr :nav_categories, :list, default: []
  attr :unread_count, :integer, default: 0
  attr :nav_query, :string, default: ""
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <.flex direction="col" class="min-h-dvh gap-[clamp(1.25rem,2vh,2.75rem)]">
      <.flex justify="center" class="w-full border-b border-neutral-200 bg-white">
        <div class="w-full px-4 sm:px-8 lg:px-12 xl:px-16">
          <.navbar
            id="top-nav"
            variant="default"
            color="white"
            border="none"
            padding="medium"
            content_position="between"
            nav_wrapper_class="flex w-full flex-wrap items-center gap-3 py-2 md:flex-nowrap md:gap-4"
          >
            <:start_content>
              <.nav_button id="nav-home" navigate={~p"/"}>
                <.flex align="center" gap="small" wrap="nowrap">
                  <.icon name="hero-cpu-chip" class="size-5 shrink-0" />
                  <span class="font-semibold tracking-tight">Odin Market</span>
                </.flex>
              </.nav_button>
            </:start_content>

            <.flex
              id="nav-links"
              align="center"
              gap="small"
              wrap="wrap"
              class="min-w-0 w-full basis-full md:w-auto md:basis-0 md:flex-1 md:flex-nowrap"
            >
              <.nav_button id="nav-browse" navigate={~p"/browse"}>Browse</.nav_button>
              <.nav_button id="nav-forum" navigate={~p"/forum"}>Forum</.nav_button>
              <%= if user = scope_user(@current_scope) do %>
                <.nav_button id="nav-dashboard" navigate={~p"/dashboard"}>Dashboard</.nav_button>
                <.flex align="center" gap="small" wrap="nowrap">
                  <.nav_button id="cart-link" navigate={~p"/cart"}>Cart</.nav_button>
                  <.badge
                    :if={cart_count(@current_scope) > 0}
                    id="cart-badge"
                    color="natural"
                    size="small"
                  >
                    {cart_count(@current_scope)}
                  </.badge>
                </.flex>
                <.nav_button id="nav-orders" navigate={~p"/dashboard/orders"}>Orders</.nav_button>
                <%= if vendor?(user) do %>
                  <.nav_button id="nav-shop" navigate={~p"/dashboard/shop"}>Shop</.nav_button>
                  <.nav_button id="nav-listings" navigate={~p"/dashboard/listings"}>
                    Listings
                  </.nav_button>
                  <.nav_button id="nav-vendor-orders" navigate={~p"/dashboard/sales"}>
                    Sales
                  </.nav_button>
                <% end %>
                <.flex align="center" gap="small" wrap="nowrap">
                  <.nav_button id="inbox-link" navigate={~p"/inbox"}>Inbox</.nav_button>
                  <.badge :if={@unread_count > 0} id="unread-badge" color="natural" size="small">
                    {@unread_count}
                  </.badge>
                </.flex>
              <% end %>
              <.form_wrapper
                id="nav-search"
                for={%{}}
                action={~p"/browse"}
                method="get"
                variant="transparent"
                rounded="small"
                space="extra_small"
                class="w-full min-w-0 basis-full md:ms-auto md:w-64 md:max-w-xs md:flex-none"
              >
                <.text_field
                  id="nav-q"
                  name="q"
                  value={@nav_query}
                  placeholder="Search"
                  size="medium"
                  rounded="small"
                  color="natural"
                />
              </.form_wrapper>
            </.flex>

            <:end_content>
              <.flex
                id="nav-account-actions"
                align="center"
                justify="end"
                gap="small"
                wrap="nowrap"
                class="ms-auto shrink-0"
              >
                <%= if user = scope_user(@current_scope) do %>
                  <.nav_button
                    :if={staff?(user)}
                    id="nav-staff"
                    navigate={~p"/staff"}
                    variant="outline"
                  >
                    Desk
                  </.nav_button>
                  <.nav_button id="nav-account" navigate={~p"/dashboard/settings"} variant="outline">
                    Settings
                  </.nav_button>
                  <.nav_button id="nav-sign-out" href={~p"/sign-out"} variant="default" color="dark">
                    Sign out
                  </.nav_button>
                <% else %>
                  <.nav_button
                    id="nav-sign-in"
                    navigate={~p"/sign-in"}
                    variant="default"
                    color="natural"
                  >
                    Sign in
                  </.nav_button>
                  <.nav_button
                    id="nav-register"
                    navigate={~p"/register"}
                    variant="default"
                    color="dark"
                  >
                    Sign up
                  </.nav_button>
                <% end %>
              </.flex>
            </:end_content>
          </.navbar>
        </div>
      </.flex>

      <.flex justify="center" class="w-full flex-1">
        <div class="odin-page w-full px-4 sm:px-8 lg:px-12 xl:px-16">
          {render_slot(@inner_block)}
        </div>
      </.flex>

      <.flex justify="center" class="w-full">
        <div class="w-full px-4 pb-8 sm:px-8 lg:px-12 xl:px-16">
          <.divider />
          <.footer
            id="site-footer"
            variant="default"
            color="white"
            border="none"
            padding="medium"
            space="small"
          >
            <.flex align="center" justify="between" gap="medium" class="w-full">
              <p>Embedded electronics. Parts, builds, and the ideas behind them.</p>
              <.flex align="center" gap="small" wrap="nowrap">
                <.nav_button id="footer-privacy" navigate={~p"/privacy"}>Privacy</.nav_button>
                <.nav_button id="footer-terms" navigate={~p"/terms"}>Terms</.nav_button>
              </.flex>
            </.flex>
          </.footer>
        </div>
      </.flex>
    </.flex>
    <.flash_group
      flash={@flash}
      position=""
      class="fixed top-4 left-1/2 z-50 w-[min(24rem,calc(100%-2rem))] -translate-x-1/2"
    />
    """
  end

  attr :id, :string, required: true
  attr :navigate, :string, default: nil
  attr :href, :string, default: nil
  attr :variant, :string, default: "transparent"
  attr :color, :string, default: "natural"
  slot :inner_block, required: true

  defp nav_button(%{href: href} = assigns) when is_binary(href) do
    ~H"""
    <.button_link
      id={@id}
      href={@href}
      variant={@variant}
      color={@color}
      size="medium"
      rounded="small"
    >
      {render_slot(@inner_block)}
    </.button_link>
    """
  end

  defp nav_button(assigns) do
    ~H"""
    <.button_link
      id={@id}
      navigate={@navigate}
      variant={@variant}
      color={@color}
      size="medium"
      rounded="small"
    >
      {render_slot(@inner_block)}
    </.button_link>
    """
  end

  defp scope_user(%{user: user}) when not is_nil(user), do: user
  defp scope_user(_), do: nil

  defp vendor?(user), do: OdinMarket.Accounts.vendor?(user)

  defp staff?(user), do: OdinMarket.Moderation.staff?(user)

  defp cart_count(%{cart_count: count}) when is_integer(count), do: count
  defp cart_count(_), do: 0
end
