defmodule OdinMarketWeb.CartLive do
  use OdinMarketWeb, :live_view

  alias OdinMarket.Accounts
  alias OdinMarket.Checkout
  alias OdinMarket.Errors
  alias OdinMarket.Orders

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    {:ok,
     socket
     |> assign(:page_title, "Cart")
     |> assign(:items, Orders.list_cart(user))
     |> assign(:form, profile_form(user))}
  end

  @impl true
  def handle_event("save-profile", params, socket) do
    case Accounts.save_profile(socket.assigns.current_user, params["profile"] || %{}) do
      {:ok, user} ->
        socket =
          socket
          |> assign(:current_user, user)
          |> assign(:current_scope, %{user: user, cart_count: length(socket.assigns.items)})
          |> assign(:form, profile_form(user))

        if params["intent"] == "pay" do
          pay(socket, user)
        else
          {:noreply, put_flash(socket, :info, "Shipping address saved.")}
        end

      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
  end

  def handle_event("update-line", %{"id" => id, "line" => line}, socket) do
    item = Enum.find(socket.assigns.items, &(&1.id == id))

    case Orders.update_cart_line(item, socket.assigns.current_user, line["qty"], line["notes"]) do
      {:ok, _} ->
        {:noreply, refresh_items(socket)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, Errors.message(reason))}
    end
  end

  def handle_event("remove-line", %{"id" => id}, socket) do
    item = Enum.find(socket.assigns.items, &(&1.id == id))

    case Orders.remove_cart_line(item, socket.assigns.current_user) do
      :ok ->
        {:noreply, refresh_items(socket)}

      {:ok, _} ->
        {:noreply, refresh_items(socket)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "That line could not be removed.")}
    end
  end

  defp pay(socket, user) do
    case Checkout.start_cart(user) do
      {:ok, url} ->
        {:noreply, redirect(socket, external: url)}

      {:error, reason} when is_atom(reason) ->
        {:noreply, put_flash(socket, :error, Errors.message(reason))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, Errors.message(:not_configured))}
    end
  end

  defp refresh_items(socket) do
    items = Orders.list_cart(socket.assigns.current_user)
    user = socket.assigns.current_user

    socket
    |> assign(:items, items)
    |> assign(:current_scope, %{user: user, cart_count: length(items)})
  end

  defp line_total(item) do
    item.listing.price_cents * item.qty + shipping_cents(item.listing)
  end

  defp profile_form(user) do
    user
    |> AshPhoenix.Form.for_update(:save_profile,
      domain: OdinMarket.Accounts,
      actor: user,
      as: "profile"
    )
    |> to_form()
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
        <h1>Cart</h1>
        <p>
          Change quantities and the shipping address, then continue to the card payment on Stripe.
        </p>

        <.flex id="cart-lines" direction="col" gap="medium">
          <.alert :if={@items == []} id="cart-empty" kind={:natural} title="Nothing in the cart">
            Browse parts and add one.
          </.alert>
          <.flex :if={@items == []} align="center" gap="medium">
            <.button_link
              navigate={~p"/browse"}
              variant="default"
              color="dark"
              size="medium"
              rounded="small"
            >
              Browse
            </.button_link>
          </.flex>
          <.card
            :for={item <- @items}
            id={"cart-item-#{item.id}"}
            variant="base"
            color="natural"
            rounded="small"
            padding="medium"
            space="medium"
          >
            <.flex align="center" gap="medium">
              <.image
                src={cover(item.listing)}
                alt=""
                rounded="small"
                width={112}
                height={112}
              />
              <.flex direction="col" gap="medium">
                <.button_link
                  navigate={~p"/l/#{item.listing.slug}"}
                  variant="transparent"
                  color="natural"
                  size="medium"
                  rounded="small"
                >
                  {item.listing.title}
                </.button_link>
                <p>{shop_name(item.listing)}</p>
                <p>{money(item.listing.price_cents)} each</p>
                <p>{shipping_label(item.listing)}</p>
                <p>{money(line_total(item))}</p>
              </.flex>
            </.flex>
            <.form_wrapper
              for={to_form(%{"qty" => item.qty, "notes" => item.notes}, as: :line)}
              id={"cart-line-#{item.id}"}
              phx-submit="update-line"
              variant="transparent"
              space="medium"
              rounded="small"
            >
              <.flex align="center" gap="medium">
                <.number_field
                  :if={item.listing.kind == :stock}
                  name="line[qty]"
                  id={"cart-qty-#{item.id}"}
                  value={item.qty}
                  label="Quantity"
                  min="1"
                  size="medium"
                  rounded="small"
                  color="natural"
                />
                <.textarea_field
                  :if={item.listing.kind == :custom}
                  name="line[notes]"
                  id={"cart-notes-#{item.id}"}
                  value={item.notes}
                  label="What should the shop build?"
                  rows="3"
                  size="medium"
                  rounded="small"
                  color="natural"
                />
                <.button
                  type="submit"
                  name="id"
                  value={item.id}
                  variant="outline"
                  color="natural"
                  size="medium"
                  rounded="small"
                >
                  Update
                </.button>
                <.button
                  type="button"
                  variant="outline"
                  color="danger"
                  size="medium"
                  rounded="small"
                  phx-click="remove-line"
                  phx-value-id={item.id}
                >
                  Remove
                </.button>
              </.flex>
            </.form_wrapper>
          </.card>
        </.flex>

        <.card
          variant="base"
          color="natural"
          rounded="small"
          padding="medium"
          space="medium"
        >
          <h2>Shipping address</h2>
          <.form_wrapper
            for={@form}
            id="cart-address"
            phx-submit="save-profile"
            variant="transparent"
            space="medium"
            rounded="small"
          >
            <.text_field
              field={@form[:display_name]}
              label="Display name"
              size="medium"
              rounded="small"
              color="natural"
            />
            <.text_field
              field={@form[:ship_name]}
              label="Recipient"
              size="medium"
              rounded="small"
              color="natural"
            />
            <.text_field
              field={@form[:ship_line1]}
              label="Street address"
              size="medium"
              rounded="small"
              color="natural"
            />
            <.text_field
              field={@form[:ship_line2]}
              label="Apartment, suite (optional)"
              size="medium"
              rounded="small"
              color="natural"
            />
            <.text_field
              field={@form[:ship_city]}
              label="City"
              size="medium"
              rounded="small"
              color="natural"
            />
            <.text_field
              field={@form[:ship_region]}
              label="State or region"
              size="medium"
              rounded="small"
              color="natural"
            />
            <.text_field
              field={@form[:ship_postal_code]}
              label="Postal code"
              size="medium"
              rounded="small"
              color="natural"
            />
            <.text_field
              field={@form[:ship_country]}
              label="Country"
              size="medium"
              rounded="small"
              color="natural"
            />
            <.flex align="center" gap="medium">
              <.button
                type="submit"
                name="intent"
                value="save"
                variant="outline"
                color="natural"
                size="medium"
                rounded="small"
              >
                Save address
              </.button>
              <.button
                :if={@items != []}
                id="pay-cart"
                type="submit"
                name="intent"
                value="pay"
                variant="default"
                color="dark"
                size="medium"
                rounded="small"
              >
                Continue to card payment
              </.button>
            </.flex>
          </.form_wrapper>
          <p>The card number is entered on Stripe, not stored here.</p>
        </.card>
      </.flex>
    </.market_layout>
    """
  end
end
