defmodule OdinMarketWeb.MarketComponents do
  use Phoenix.Component
  use OdinMarketWeb.Components.MishkaComponents
  use OdinMarketWeb, :verified_routes

  alias OdinMarket.Accounts.Address
  alias OdinMarketWeb.Layouts

  attr :flash, :map, required: true
  attr :current_scope, :map, default: nil
  attr :nav_categories, :list, default: []
  attr :unread_count, :integer, default: 0
  attr :nav_query, :string, default: ""
  slot :inner_block, required: true

  def market_layout(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      nav_categories={@nav_categories}
      unread_count={@unread_count}
      nav_query={@nav_query}
    >
      {render_slot(@inner_block)}
    </Layouts.app>
    """
  end

  attr :vendor?, :boolean, default: false
  attr :current, :atom, default: nil

  def dashboard_links(assigns) do
    ~H"""
    <.flex id="account-links" align="center" gap="small" class="flex-wrap">
      <.dash_link current={@current} name={:overview} navigate={~p"/dashboard"}>
        Overview
      </.dash_link>
      <.dash_link current={@current} name={:orders} navigate={~p"/dashboard/orders"}>
        Orders
      </.dash_link>
      <.dash_link current={@current} name={:billing} navigate={~p"/dashboard/billing"}>
        Billing
      </.dash_link>
      <.dash_link current={@current} name={:settings} navigate={~p"/dashboard/settings"}>
        Settings
      </.dash_link>
      <.dash_link :if={@vendor?} current={@current} name={:shop} navigate={~p"/dashboard/shop"}>
        Shop
      </.dash_link>
      <.dash_link
        :if={@vendor?}
        current={@current}
        name={:listings}
        navigate={~p"/dashboard/listings"}
      >
        Listings
      </.dash_link>
      <.dash_link :if={@vendor?} current={@current} name={:sales} navigate={~p"/dashboard/sales"}>
        Sales
      </.dash_link>
    </.flex>
    """
  end

  attr :current, :atom, default: nil
  attr :name, :atom, required: true
  attr :navigate, :string, required: true
  slot :inner_block, required: true

  defp dash_link(assigns) do
    assigns = assign(assigns, :active?, assigns.current == assigns.name)

    ~H"""
    <.button_link
      navigate={@navigate}
      variant={if(@active?, do: "default", else: "outline")}
      color={if(@active?, do: "dark", else: "natural")}
      size="medium"
      rounded="small"
    >
      {render_slot(@inner_block)}
    </.button_link>
    """
  end

  attr :listing, :map, required: true

  def listing_card(assigns) do
    ~H"""
    <.card
      id={"listing-#{@listing.id}"}
      variant="base"
      color="natural"
      rounded="small"
      padding="medium"
      space="small"
      class="flex h-full flex-col"
    >
      <.image
        src={cover(@listing)}
        alt=""
        rounded="small"
        class="aspect-[4/3] h-auto w-full object-cover"
      />
      <h3 class="line-clamp-2">{@listing.title}</h3>
      <p>{money(@listing.price_cents)}</p>
      <p :if={shop_name(@listing)} class="text-sm">{shop_name(@listing)}</p>
      <div class="mt-auto pt-2">
        <.button_link
          navigate={~p"/l/#{@listing.slug}"}
          variant="default"
          color="dark"
          size="small"
          rounded="small"
        >
          View
        </.button_link>
      </div>
    </.card>
    """
  end

  attr :specs, :map, default: %{}

  def spec_table(assigns) do
    assigns = assign(assigns, :rows, spec_rows(assigns.specs))

    ~H"""
    <.table
      :if={@rows != []}
      id="specs"
      rows={@rows}
      variant="base"
      color="natural"
      rounded="small"
      padding="medium"
    >
      <:col :let={row} label="Spec">{row.label}</:col>
      <:col :let={row} label="Value">{row.value}</:col>
    </.table>
    """
  end

  def cover(listing) do
    case image_list(listing) do
      [%{url: url} | _] when is_binary(url) and url != "" -> url
      _ -> OdinMarket.Uploads.placeholder()
    end
  end

  def money(cents), do: OdinMarket.Money.format_cents(cents)

  def shipping_cents(%{shipping_cents: cents}) when is_integer(cents) and cents >= 0, do: cents
  def shipping_cents(_), do: 0

  def shipping_label(record) do
    case shipping_cents(record) do
      0 -> "Free shipping"
      cents -> "Shipping #{money(cents)}"
    end
  end

  def charge_cents(%{unit_price_cents: price, qty: qty} = record)
      when is_integer(price) and is_integer(qty) do
    price * qty + shipping_cents(record)
  end

  def charge_cents(%{price_cents: price, qty: qty} = record)
      when is_integer(price) and is_integer(qty) do
    price * qty + shipping_cents(record)
  end

  def category_label(%{parent: %{name: parent}, name: name})
      when is_binary(parent) and is_binary(name) do
    parent <> " · " <> name
  end

  def category_label(%{name: name}) when is_binary(name), do: name
  def category_label(_), do: nil

  def status_label(status) do
    status
    |> to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  def shop_name(%{vendor: %{shop_name: name}}) when is_binary(name), do: name
  def shop_name(_), do: nil

  def website_href("https://" <> _ = url), do: url
  def website_href("http://" <> _ = url), do: url
  def website_href(_), do: nil

  def shipping_lines(record) when is_map(record) do
    city_line =
      [
        Map.get(record, :ship_city),
        Map.get(record, :ship_region),
        Map.get(record, :ship_postal_code)
      ]
      |> Enum.filter(&Address.present?/1)
      |> Enum.join(", ")

    [
      Map.get(record, :ship_name),
      Map.get(record, :ship_line1),
      Map.get(record, :ship_line2),
      city_line,
      Map.get(record, :ship_country)
    ]
    |> Enum.filter(&Address.present?/1)
  end

  def shipping_lines(_), do: []

  attr :record, :map, required: true

  def shipping_address(assigns) do
    assigns = assign(assigns, :lines, shipping_lines(assigns.record))

    ~H"""
    <.flex :if={@lines != []} id="shipping-address" direction="col" gap="medium">
      <p>Shipping address</p>
      <p :for={line <- @lines}>{line}</p>
    </.flex>
    """
  end

  attr :form, :any, required: true
  attr :category_groups, :list, required: true
  attr :photo_error, :string, default: nil
  attr :listing, :any, default: nil
  attr :uploads, :any, default: %{}

  def listing_editor(assigns) do
    ~H"""
    <.card variant="base" color="natural" rounded="small" padding="medium" space="medium">
      <.form_wrapper
        for={@form}
        id="listing-form"
        phx-change="validate"
        phx-submit="save"
        variant="transparent"
        space="medium"
        rounded="small"
      >
        <.text_field
          field={@form[:title]}
          label="Title"
          size="medium"
          rounded="small"
          color="natural"
        />
        <.textarea_field
          field={@form[:description]}
          label="Description"
          rows="5"
          size="medium"
          rounded="small"
          color="natural"
        />
        <p>What the part is, what it fits, and anything a buyer should know.</p>
        <.native_select
          field={@form[:category_id]}
          label="Category"
          size="medium"
          rounded="small"
          color="natural"
        >
          <:option value="">Choose a category</:option>
          <.select_option_group
            :for={group <- @category_groups}
            :if={group.children != []}
            id={"listing-category-#{group.parent.slug}"}
            label={group.parent.name}
          >
            <:option
              :for={category <- group.children}
              value={category.id}
              selected={category_selected?(@form, category)}
            >
              {category.name}
            </:option>
          </.select_option_group>
          <:option
            :for={group <- @category_groups}
            :if={group.children == []}
            value={group.parent.id}
            selected={category_selected?(@form, group.parent)}
          >
            {group.parent.name}
          </:option>
        </.native_select>
        <p>Pick the specific kind, such as HF radio. A family name is only for browsing.</p>
        <.number_field
          field={@form[:price_cents]}
          label="Price (cents)"
          size="medium"
          rounded="small"
          color="natural"
        />
        <.number_field
          field={@form[:shipping_cents]}
          label="Shipping fee (cents)"
          size="medium"
          rounded="small"
          color="natural"
        />
        <p>
          Price and shipping are cents. 1250 is $12.50. Use 0 when the shop ships this part for free.
        </p>
        <.flex id="listing-photos" direction="col" gap="medium">
          <p>Photos</p>
          <p>
            Upload up to 4. The first photo is the cover. JPG, PNG, or WEBP, 5 MB each.
            A new listing needs a photo before it can be published. Save as a draft if the photo is not ready.
          </p>
          <.alert :if={@photo_error} id="listing-photo-error" kind={:danger} title="Photo required">
            {@photo_error}
          </.alert>
          <.alert
            :if={@listing && image_list(@listing) == []}
            id="listing-photo-missing"
            kind={:natural}
            title="No photo yet"
          >
            Buyers only see a placeholder until a photo is uploaded.
          </.alert>
          <.grid :if={@listing && image_list(@listing) != []} cols="four" gap="medium">
            <.flex
              :for={image <- image_list(@listing)}
              id={"image-#{image.id}"}
              direction="col"
              gap="medium"
            >
              <.image src={image.url} alt="" rounded="small" width={160} height={160} />
              <.button
                type="button"
                variant="outline"
                color="natural"
                size="medium"
                rounded="small"
                phx-click="delete-image"
                phx-value-id={image.id}
              >
                Remove
              </.button>
            </.flex>
          </.grid>
          <.file_field
            :if={upload_config(@uploads, :images)}
            id="listing-photo-input"
            uploads={@uploads}
            target={:images}
            dropzone
            dropzone_type="image"
            label="Add photos"
            size="medium"
            rounded="small"
            color="natural"
          />
        </.flex>
        <.native_select
          field={@form[:kind]}
          label="How it sells"
          size="medium"
          rounded="small"
          color="natural"
        >
          <:option value="stock" selected={to_string(@form[:kind].value) == "stock"}>
            In stock
          </:option>
          <:option value="custom" selected={to_string(@form[:kind].value) == "custom"}>
            Custom build
          </:option>
        </.native_select>
        <.number_field
          :if={to_string(@form[:kind].value) != "custom"}
          field={@form[:qty_available]}
          label="Quantity available"
          size="medium"
          rounded="small"
          color="natural"
        />
        <.number_field
          :if={to_string(@form[:kind].value) == "custom"}
          field={@form[:lead_days]}
          label="Lead time (days)"
          size="medium"
          rounded="small"
          color="natural"
        />
        <.text_field
          field={@form[:voltage]}
          label="Voltage"
          size="medium"
          rounded="small"
          color="natural"
        />
        <.text_field
          field={@form[:package]}
          label="Package"
          size="medium"
          rounded="small"
          color="natural"
        />
        <.text_field
          field={@form[:interface]}
          label="Interface"
          size="medium"
          rounded="small"
          color="natural"
        />
        <.text_field field={@form[:mcu]} label="MCU" size="medium" rounded="small" color="natural" />
        <.native_select
          field={@form[:status]}
          label="Visibility"
          size="medium"
          rounded="small"
          color="natural"
        >
          <:option value="draft" selected={to_string(@form[:status].value) != "active"}>
            Draft
          </:option>
          <:option value="active" selected={to_string(@form[:status].value) == "active"}>
            Active
          </:option>
        </.native_select>
        <.button type="submit" variant="default" color="dark" size="medium" rounded="small">
          Save listing
        </.button>
      </.form_wrapper>
    </.card>

    <.flex :if={@listing} direction="col" gap="medium">
      <.button
        type="button"
        variant="outline"
        color="natural"
        size="medium"
        rounded="small"
        phx-click={show_modal("archive-modal")}
      >
        Archive listing
      </.button>
      <.modal
        id="archive-modal"
        title="Archive listing"
        variant="base"
        color="natural"
        rounded="small"
        padding="medium"
      >
        <.flex direction="col" gap="medium">
          <p>Archived listings leave the market. The record stays on the shop.</p>
          <.button
            id="archive-listing"
            type="button"
            variant="default"
            color="danger"
            size="medium"
            rounded="small"
            phx-click="archive"
          >
            Archive listing
          </.button>
        </.flex>
      </.modal>
    </.flex>
    """
  end

  def image_list(%{images: images}) when is_list(images), do: images
  def image_list(_), do: []

  defp category_selected?(form, category) do
    to_string(category.id) == to_string(form[:category_id].value)
  end

  defp upload_config(uploads, name) when is_map(uploads), do: Map.get(uploads, name)
  defp upload_config(_, _), do: nil

  def spec_rows(specs) when is_map(specs) do
    [
      {"Voltage", specs["voltage"]},
      {"Package", specs["package"]},
      {"Interface", specs["interface"]},
      {"MCU", specs["mcu"]}
    ]
    |> Enum.filter(fn {_label, value} -> is_binary(value) and String.trim(value) != "" end)
    |> Enum.map(fn {label, value} -> %{label: label, value: value} end)
  end

  def spec_rows(_), do: []

  attr :id, :string, required: true
  attr :open?, :boolean, default: false

  def report_box(assigns) do
    ~H"""
    <div id={"report-#{@id}"}>
      <.button
        :if={not @open?}
        id={"report-open-#{@id}"}
        type="button"
        variant="transparent"
        color="natural"
        size="small"
        rounded="small"
        phx-click="open-report"
        phx-value-id={@id}
      >
        Report
      </.button>
      <.form_wrapper
        :if={@open?}
        for={%{}}
        id={"report-form-#{@id}"}
        phx-submit="file-report"
        variant="transparent"
        space="small"
        rounded="small"
      >
        <input type="hidden" name="report[target_id]" value={@id} />
        <.native_select
          id={"report-reason-#{@id}"}
          name="report[reason]"
          label="Reason"
          size="medium"
          rounded="small"
          color="natural"
        >
          <:option value="spam">Spam</:option>
          <:option value="harassment">Harassment</:option>
          <:option value="scam">Scam</:option>
          <:option value="off_topic">Off topic</:option>
          <:option value="other">Other</:option>
        </.native_select>
        <.textarea_field
          id={"report-note-#{@id}"}
          name="report[note]"
          value=""
          label="Note"
          rows="3"
          size="medium"
          rounded="small"
          color="natural"
        />
        <.flex align="center" gap="small" class="flex-wrap">
          <.button type="submit" variant="default" color="dark" size="small" rounded="small">
            Send report
          </.button>
          <.button
            type="button"
            variant="outline"
            color="natural"
            size="small"
            rounded="small"
            phx-click="cancel-report"
          >
            Cancel
          </.button>
        </.flex>
      </.form_wrapper>
    </div>
    """
  end
end
