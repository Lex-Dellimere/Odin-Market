defmodule OdinMarketWeb.ShopLive do
  use OdinMarketWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Shop", shop: nil, listings: [], missing: false)}
  end

  @impl true
  def handle_params(%{"slug" => slug}, _uri, socket) do
    case OdinMarket.Accounts.get_shop_by_slug(slug) do
      {:ok, shop} when not is_nil(shop) ->
        listings =
          case OdinMarket.Catalog.search(%{"vendor_id" => shop.id}) do
            {:ok, %{results: results}} -> results
            _ -> []
          end

        {:noreply,
         socket
         |> assign(:page_title, shop.shop_name)
         |> assign(:shop, shop)
         |> assign(:listings, listings)
         |> assign(:missing, false)}

      _ ->
        {:noreply,
         assign(socket, shop: nil, listings: [], missing: true, page_title: "Not found")}
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
      <.alert :if={@missing} id="not-found" kind={:danger} title="Not found">
        That shop is not available.
      </.alert>

      <.flex :if={@shop} id="shop" direction="col" gap="medium">
        <.flex align="center" gap="medium">
          <.avatar size="medium" rounded="small" color="natural">{initial(@shop.shop_name)}</.avatar>
          <.flex direction="col" gap="medium">
            <h1>{@shop.shop_name}</h1>
            <p :if={@shop.location}>{@shop.location}</p>
            <p :if={@shop.bio}>{@shop.bio}</p>
            <.button_link
              :if={website_href(@shop.website)}
              id="shop-website"
              href={website_href(@shop.website)}
              variant="transparent"
              color="natural"
              size="medium"
              rounded="small"
              rel="noreferrer"
            >
              {website_href(@shop.website)}
            </.button_link>
          </.flex>
        </.flex>
        <.alert :if={@listings == []} kind={:natural} title="No active listings">
          This shop has nothing public right now.
        </.alert>
        <.grid
          :if={@listings != []}
          cols="grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5"
          gap="gap-6"
        >
          <.listing_card :for={listing <- @listings} listing={listing} />
        </.grid>
      </.flex>
    </.market_layout>
    """
  end

  defp initial(name) when is_binary(name) and name != "" do
    name |> String.trim() |> String.first() |> String.upcase()
  end

  defp initial(_), do: "S"
end
