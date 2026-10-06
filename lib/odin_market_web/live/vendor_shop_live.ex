defmodule OdinMarketWeb.VendorShopLive do
  use OdinMarketWeb, :live_view

  alias OdinMarket.Accounts.VendorProfile

  @impl true
  def mount(_params, _session, socket) do
    form =
      socket.assigns.vendor_profile
      |> AshPhoenix.Form.for_update(:update_shop,
        domain: OdinMarket.Accounts,
        actor: socket.assigns.current_user,
        as: "shop"
      )
      |> to_form()

    {:ok, assign(socket, page_title: "Shop", form: form)}
  end

  @impl true
  def handle_event("validate", %{"shop" => params}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"shop" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, profile} ->
        {:noreply,
         socket
         |> assign(:vendor_profile, profile)
         |> put_flash(:info, "Shop updated.")}

      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
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
        <h1>Shop profile</h1>
        <.dashboard_links vendor?={true} current={:shop} />
        <p>Public address: {shop_path(@vendor_profile)}</p>
        <.card variant="base" color="natural" rounded="small" padding="medium" space="medium">
          <.form_wrapper
            for={@form}
            id="shop-form"
            phx-change="validate"
            phx-submit="save"
            variant="transparent"
            space="medium"
            rounded="small"
          >
            <.text_field
              field={@form[:shop_name]}
              label="Shop name"
              size="medium"
              rounded="small"
              color="natural"
            />
            <.textarea_field
              field={@form[:bio]}
              label="Bio"
              rows="4"
              size="medium"
              rounded="small"
              color="natural"
            />
            <.text_field
              field={@form[:location]}
              label="Location"
              size="medium"
              rounded="small"
              color="natural"
            />
            <.text_field
              field={@form[:website]}
              label="Website"
              placeholder="https://"
              size="medium"
              rounded="small"
              color="natural"
            />
            <.button type="submit" variant="default" color="dark" size="medium" rounded="small">
              Save shop
            </.button>
          </.form_wrapper>
        </.card>
      </.flex>
    </.market_layout>
    """
  end

  defp shop_path(%VendorProfile{slug: slug}), do: "/shop/#{slug}"
  defp shop_path(_), do: "/shop"
end
