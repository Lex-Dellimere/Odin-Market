defmodule OdinMarketWeb.ListingLive do
  use OdinMarketWeb, :live_view

  alias OdinMarket.Catalog
  alias OdinMarket.Errors
  alias OdinMarket.Messaging

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Listing", listing: nil, missing: false, reporting: false)}
  end

  @impl true
  def handle_params(%{"slug" => slug}, _uri, socket) do
    case Catalog.get_by_slug(slug) do
      {:ok, listing} ->
        {:noreply,
         socket
         |> assign(:page_title, listing.title)
         |> assign(:listing, listing)
         |> assign(:missing, false)
         |> assign(:reporting, false)
         |> assign(:buy, to_form(%{"qty" => "1", "notes" => ""}, as: :buy))}

      _ ->
        {:noreply, assign(socket, listing: nil, missing: true, page_title: "Not found")}
    end
  end

  @impl true
  def handle_event("buy", %{"buy" => params}, socket) do
    user = socket.assigns.current_user
    listing = socket.assigns.listing

    cond do
      is_nil(user) ->
        {:noreply, push_navigate(socket, to: ~p"/sign-in")}

      owner?(socket, listing) ->
        {:noreply, put_flash(socket, :error, Errors.message(:own_listing))}

      true ->
        case OdinMarket.Orders.add_to_cart(
               user,
               listing.id,
               params["qty"] || "1",
               params["notes"]
             ) do
          {:ok, _} ->
            {:noreply, push_navigate(socket, to: ~p"/cart")}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, Errors.message(reason))}
        end
    end
  end

  def handle_event("message", _params, socket) do
    user = socket.assigns.current_user
    listing = socket.assigns.listing

    cond do
      is_nil(user) ->
        {:noreply, push_navigate(socket, to: ~p"/sign-in")}

      owner?(socket, listing) ->
        {:noreply, put_flash(socket, :error, Errors.message(:own_listing))}

      true ->
        case Messaging.open_for_listing(user, listing.id) do
          {:ok, conversation} ->
            {:noreply, push_navigate(socket, to: ~p"/inbox/#{conversation.id}")}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, Errors.message(reason))}
        end
    end
  end

  def handle_event("open-report", %{"id" => _id}, socket) do
    {:noreply, assign(socket, :reporting, true)}
  end

  def handle_event("cancel-report", _params, socket) do
    {:noreply, assign(socket, :reporting, false)}
  end

  def handle_event("file-report", %{"report" => params}, socket) do
    attrs = %{
      target_type: :listing,
      target_id: params["target_id"],
      reason: params["reason"],
      note: params["note"]
    }

    case OdinMarket.Moderation.file_report(socket.assigns.current_user, attrs) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:reporting, false)
         |> put_flash(:info, "Report sent.")}

      {:error, message} when is_binary(message) ->
        {:noreply, put_flash(socket, :error, message)}

      _ ->
        {:noreply, put_flash(socket, :error, "That report could not be sent.")}
    end
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :images, image_list(assigns.listing))

    ~H"""
    <.market_layout
      flash={@flash}
      current_scope={@current_scope}
      nav_categories={@nav_categories}
      unread_count={@unread_count}
      nav_query={@nav_query}
    >
      <.alert :if={@missing} id="not-found" kind={:danger} title="Not found">
        That listing is not available.
      </.alert>

      <.card
        :if={@listing}
        id="listing"
        variant="base"
        color="natural"
        rounded="small"
        padding="medium"
        space="medium"
      >
        <.grid cols="grid-cols-1 lg:grid-cols-2" gap="gap-8 lg:gap-12" class="w-full items-start">
          <div class="min-w-0">
            <.carousel :if={length(@images) > 1} id="listing-photos">
              <:slide :for={image <- @images} image={image.url} />
            </.carousel>
            <.image
              :if={length(@images) <= 1}
              id="listing-photos"
              src={cover(@listing)}
              alt=""
              rounded="small"
              class="aspect-[4/3] h-auto max-h-[60vh] w-full object-cover"
            />
          </div>
          <.flex direction="col" gap="gap-4" class="min-w-0">
            <h1>{@listing.title}</h1>
            <p>{money(@listing.price_cents)}</p>
            <p>{shipping_label(@listing)}</p>
            <p>{@listing.description}</p>
            <p :if={@listing.kind == :stock}>{stock_label(@listing.qty_available)} available</p>
            <p :if={@listing.kind == :custom}>Lead time: {@listing.lead_days} days</p>
            <.spec_table specs={@listing.specs || %{}} />
            <p>{shop_name(@listing) || "Shop"}</p>
            <.button_link
              :if={@listing.vendor}
              navigate={~p"/shop/#{@listing.vendor.slug}"}
              variant="outline"
              color="natural"
              size="medium"
              rounded="small"
            >
              View shop
            </.button_link>
            <.button_link
              :if={@listing.vendor && website_href(@listing.vendor.website)}
              href={website_href(@listing.vendor.website)}
              variant="transparent"
              color="natural"
              size="medium"
              rounded="small"
            >
              {website_href(@listing.vendor.website)}
            </.button_link>
            <%= if owner?(@current_user, @listing) do %>
              <p>This is your listing.</p>
            <% else %>
              <%= if buyable?(@listing) do %>
                <.form_wrapper
                  for={@buy}
                  id="buy-form"
                  phx-submit="buy"
                  variant="transparent"
                  space="medium"
                  rounded="small"
                >
                  <.number_field
                    :if={@listing.kind == :stock}
                    field={@buy[:qty]}
                    label="Quantity"
                    min="1"
                    size="medium"
                    rounded="small"
                    color="natural"
                  />
                  <.textarea_field
                    :if={@listing.kind == :custom}
                    field={@buy[:notes]}
                    label="What should the shop build?"
                    rows="4"
                    size="medium"
                    rounded="small"
                    color="natural"
                  />
                  <:actions>
                    <.button
                      type="submit"
                      variant="default"
                      color="dark"
                      size="medium"
                      rounded="small"
                    >
                      Add to cart
                    </.button>
                  </:actions>
                </.form_wrapper>
              <% else %>
                <p>Out of stock.</p>
              <% end %>
              <.button
                id="message-seller"
                type="button"
                variant="outline"
                color="natural"
                size="medium"
                rounded="small"
                phx-click="message"
              >
                Message seller
              </.button>
              <.report_box
                :if={@current_user}
                id={to_string(@listing.id)}
                open?={@reporting}
              />
            <% end %>
          </.flex>
        </.grid>
      </.card>
    </.market_layout>
    """
  end

  defp owner?(%{id: user_id}, %{vendor: %{user_id: vendor_user_id}}),
    do: user_id == vendor_user_id

  defp owner?(_user, _listing), do: false

  defp buyable?(%{kind: :custom}), do: true
  defp buyable?(%{kind: :stock, qty_available: qty}) when is_integer(qty) and qty > 0, do: true
  defp buyable?(_), do: false

  defp stock_label(nil), do: "0"
  defp stock_label(qty), do: qty
end
