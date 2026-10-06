defmodule OdinMarketWeb.HomeLive do
  use OdinMarketWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Home")
     |> assign(:listings, [])
     |> assign(:families, [])}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    listings =
      case OdinMarket.Catalog.search(%{}) do
        {:ok, %{results: results}} -> Enum.take(results, 8)
        _ -> []
      end

    families =
      socket.assigns.nav_categories
      |> OdinMarket.Catalog.families()
      |> Enum.sort_by(& &1.name)

    {:noreply,
     socket
     |> assign(:listings, listings)
     |> assign(:families, families)}
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
      <.flex direction="col" gap="gap-[clamp(2.5rem,4vh,6rem)]">
        <.grid
          id="home-hero"
          cols="grid-cols-1 lg:grid-cols-[minmax(0,1.5fr)_minmax(14rem,20vw)]"
          gap="gap-8 lg:gap-[clamp(1.5rem,2.4vw,3.5rem)]"
          class="odin-hero w-full items-stretch"
        >
          <.jumbotron
            variant="transparent"
            padding=""
            space="space-y-[clamp(1rem,1.6vh,1.75rem)]"
            border_size="none"
            class="flex h-full flex-col justify-center"
          >
            <h1 class="hero-title">Make what you have in mind.</h1>
            <p class="lede">
              Odin is a market for embedded electronics and the people who design them. Search boards, modules, sensors, power, and radio parts. Buy what is in stock, or ask for a board to be built.
            </p>
            <p>
              One account can buy and sell. A Vendor subscription opens the shop: A$25 a month, A$70 every 3 months, or A$240 a year. The forum is for circuits, bring-up, and ideas that are not ready to list.
            </p>
            <.flex align="center" gap="small" class="pt-1">
              <.button_link
                id="hero-browse"
                navigate={~p"/browse"}
                variant="default"
                color="dark"
                size="medium"
                rounded="small"
              >
                Shop the market
              </.button_link>
              <%= cond do %>
                <% OdinMarket.Accounts.vendor?(@current_user) -> %>
                  <.button_link
                    id="hero-dashboard"
                    navigate={~p"/dashboard"}
                    variant="outline"
                    color="natural"
                    size="medium"
                    rounded="small"
                  >
                    Dashboard
                  </.button_link>
                <% @current_user -> %>
                  <.button_link
                    id="hero-vendor"
                    navigate={~p"/vendor/pricing"}
                    variant="outline"
                    color="natural"
                    size="medium"
                    rounded="small"
                  >
                    Become a vendor
                  </.button_link>
                <% true -> %>
                  <.button_link
                    id="hero-register"
                    navigate={~p"/register"}
                    variant="outline"
                    color="natural"
                    size="medium"
                    rounded="small"
                  >
                    Sign up
                  </.button_link>
              <% end %>
            </.flex>
          </.jumbotron>
          <div class="odin-hero-frame self-center">
            <.image
              id="home-hero-image"
              src={~p"/images/landing-hero.jpg"}
              alt="A handmade aluminum device, a circuit board, and loose components on a wood bench"
              width={1216}
              height={688}
              class="odin-hero-photo"
            />
          </div>
        </.grid>

        <div
          :if={@families != []}
          id="home-categories"
          class="odin-marquee"
          aria-label="Shop by category"
        >
          <div class="odin-marquee-track">
            <%= for copy <- 0..1 do %>
              <div
                class={["odin-marquee-group", copy == 1 && "odin-marquee-copy"]}
                aria-hidden={if(copy == 1, do: "true")}
              >
                <%= for pass <- 0..2, category <- @families do %>
                  <.button_link
                    id={if(copy == 0 and pass == 0, do: "home-category-#{category.slug}")}
                    navigate={~p"/browse?#{[category_id: to_string(category.id)]}"}
                    variant="outline"
                    color="natural"
                    size="medium"
                    rounded="full"
                    class={[
                      "shrink-0",
                      (copy == 1 or pass > 0) && "odin-marquee-extra"
                    ]}
                    tabindex={if(copy == 1 or pass > 0, do: "-1")}
                    aria-hidden={if(copy == 1 or pass > 0, do: "true")}
                  >
                    {category.name}
                  </.button_link>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>

        <.flex id="latest-listings" direction="col" gap="gap-6">
          <.flex align="center" justify="between" gap="medium">
            <h2>New on the market</h2>
            <.button_link
              navigate={~p"/browse"}
              variant="outline"
              color="natural"
              size="medium"
              rounded="small"
            >
              View all
            </.button_link>
          </.flex>
          <.alert :if={@listings == []} id="home-empty" kind={:natural} title="No listings yet">
            Boards, modules, and tools show up here once a vendor publishes them.
          </.alert>
          <.grid
            :if={@listings != []}
            cols="grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5"
            gap="gap-6"
            class="w-full items-stretch"
          >
            <.listing_card :for={listing <- @listings} listing={listing} />
          </.grid>
        </.flex>

        <.flex id="how-it-works" direction="col" gap="gap-6">
          <h2>How it works</h2>
          <.grid
            cols="grid-cols-1 md:grid-cols-3"
            gap="gap-[clamp(1rem,1.6vw,2rem)]"
            class="w-full"
          >
            <.card
              variant="base"
              color="natural"
              rounded="small"
              padding="p-[clamp(1.25rem,1.6vw,2.25rem)]"
              space="small"
            >
              <h3>1. Find</h3>
              <p>
                Search modules, boards, sensors, power, and radio parts. Filter by category, price, and what is in stock. The header search is there when you already know the name.
              </p>
            </.card>
            <.card
              variant="base"
              color="natural"
              rounded="small"
              padding="p-[clamp(1.25rem,1.6vw,2.25rem)]"
              space="small"
            >
              <h3>2. Build</h3>
              <p>
                Buy a stock part, or message the person who designed a board and ask them to build one. The order, the shipping address, and that conversation stay on the account.
              </p>
            </.card>
            <.card
              variant="base"
              color="natural"
              rounded="small"
              padding="p-[clamp(1.25rem,1.6vw,2.25rem)]"
              space="small"
            >
              <h3>3. Share</h3>
              <p>
                The forum is for circuits, bring-up, and half-formed ideas. A Vendor subscription is what puts a product on the market. You can buy and post without one.
              </p>
            </.card>
          </.grid>
        </.flex>

        <.grid
          id="for-vendors"
          cols="grid-cols-1 lg:grid-cols-2"
          gap="gap-8 lg:gap-[clamp(1.5rem,2.4vw,3.5rem)]"
          class="odin-split w-full items-stretch"
        >
          <.image
            src={~p"/images/landing-build.jpg"}
            alt="A small handmade instrument with a walnut face and a warm lamp"
            width={1168}
            height={784}
            rounded="large"
            class="odin-shot"
          />
          <.flex direction="col" gap="gap-5" class="justify-center">
            <h2>For vendors</h2>
            <p>
              One account can buy and sell. Vendor is a subscription: A$25 a month, A$70 every 3 months, or A$240 a year. It opens a shop, listings, and a sales page for embedded hardware. If the subscription lapses, the shop comes off the market and the history stays.
            </p>
            <%= cond do %>
              <% OdinMarket.Accounts.vendor?(@current_user) -> %>
                <.button_link
                  navigate={~p"/dashboard"}
                  variant="default"
                  color="dark"
                  size="medium"
                  rounded="small"
                  class="self-start"
                >
                  Open dashboard
                </.button_link>
              <% @current_user -> %>
                <.button_link
                  navigate={~p"/vendor/pricing"}
                  variant="default"
                  color="dark"
                  size="medium"
                  rounded="small"
                  class="self-start"
                >
                  See Vendor pricing
                </.button_link>
              <% true -> %>
                <.button_link
                  navigate={~p"/register"}
                  variant="outline"
                  color="natural"
                  size="medium"
                  rounded="small"
                  class="self-start"
                >
                  Create an account
                </.button_link>
            <% end %>
          </.flex>
        </.grid>

        <.grid
          id="for-makers"
          cols="grid-cols-1 lg:grid-cols-2"
          gap="gap-8 lg:gap-[clamp(1.5rem,2.4vw,3.5rem)]"
          class="odin-split w-full items-stretch"
        >
          <.flex direction="col" gap="gap-5" class="justify-center">
            <h2>Parts, and the ideas around them</h2>
            <p>
              This market stays on embedded electronics: boards, modules, sensors, power, radio, and the tools used to build them. The categories across the page are the same ones used to filter the market.
            </p>
            <.button_link
              navigate={~p"/browse"}
              variant="outline"
              color="natural"
              size="medium"
              rounded="small"
              class="self-start"
            >
              Browse the market
            </.button_link>
          </.flex>
          <.image
            src={~p"/images/landing-components.jpg"}
            alt="Boards, sensors, headers, and wire arranged on a light surface"
            width={1168}
            height={784}
            rounded="large"
            class="odin-shot"
          />
        </.grid>
      </.flex>
    </.market_layout>
    """
  end
end
