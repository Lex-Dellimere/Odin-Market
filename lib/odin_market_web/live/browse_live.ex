defmodule OdinMarketWeb.BrowseLive do
  use OdinMarketWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Browse")
     |> assign(:listings, [])
     |> assign(:page, 1)
     |> assign(:total_pages, 1)
     |> assign(:filters, empty_filters())}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filters = filters_from(params)

    {listings, page, total_pages} =
      case OdinMarket.Catalog.search(params) do
        {:ok, result} -> {result.results, result.page, result.total_pages}
        _ -> {[], 1, 1}
      end

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> assign(:nav_query, filters.q)
     |> assign(:listings, listings)
     |> assign(:page, page)
     |> assign(:total_pages, total_pages)}
  end

  @impl true
  def handle_event("pagination", params, socket) do
    page =
      case params["action"] do
        "select" -> positive(params["page"], socket.assigns.page)
        "next" -> socket.assigns.page + 1
        "previous" -> max(socket.assigns.page - 1, 1)
        "first" -> 1
        "last" -> socket.assigns.total_pages
        _ -> socket.assigns.page
      end

    {:noreply, push_patch(socket, to: browse_path(socket.assigns.filters, page))}
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
      <.flex direction="col" gap="gap-8">
        <.flex align="center" justify="between" gap="medium" class="lg:hidden">
          <h1>Browse</h1>
          <.button
            type="button"
            variant="outline"
            color="natural"
            size="small"
            rounded="small"
            phx-click={show_drawer("filters-drawer", "left")}
          >
            Filters
          </.button>
        </.flex>
        <.drawer id="filters-drawer" title="Filters">
          <.filters id_prefix="browse-drawer" filters={@filters} categories={@nav_categories} />
        </.drawer>

        <.grid
          cols="grid-cols-1 lg:grid-cols-[minmax(16rem,18vw)_minmax(0,1fr)]"
          gap="gap-8 lg:gap-12"
          class="mb-4 hidden w-full items-end lg:grid"
        >
          <h2>Filters</h2>
          <h1>Browse</h1>
        </.grid>
        <.grid
          id="browse-layout"
          cols="grid-cols-1 lg:grid-cols-[minmax(16rem,18vw)_minmax(0,1fr)]"
          gap="gap-8 lg:gap-12"
          class="w-full items-start"
        >
          <div class="hidden lg:block">
            <.card variant="base" color="natural" rounded="small" padding="medium" space="small">
              <.filters id_prefix="browse" filters={@filters} categories={@nav_categories} />
            </.card>
          </div>

          <.flex direction="col" gap="medium" class="min-w-0">
            <.grid :if={!connected?(@socket)} id="browse-skeleton" cols="two" gap="medium">
              <.skeleton :for={_ <- 1..4} />
            </.grid>

            <.flex :if={connected?(@socket)} id="browse-results" direction="col" gap="gap-6">
              <.alert :if={@listings == []} id="browse-empty" kind={:natural} title="No matches">
                Try a shorter search or clear a filter.
              </.alert>
              <.grid
                cols="grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4"
                gap="gap-6"
                class="w-full items-stretch"
              >
                <.listing_card :for={listing <- @listings} listing={listing} />
              </.grid>
              <.pagination id="browse-pages" total={@total_pages} active={@page} />
            </.flex>
          </.flex>
        </.grid>
      </.flex>
    </.market_layout>
    """
  end

  attr :id_prefix, :string, required: true
  attr :filters, :map, required: true
  attr :categories, :list, required: true

  defp filters(assigns) do
    assigns =
      assign(assigns, :category_groups, OdinMarket.Catalog.category_menu(assigns.categories))

    ~H"""
    <.form_wrapper
      id={"#{@id_prefix}-filters"}
      for={%{}}
      action={~p"/browse"}
      method="get"
      variant="transparent"
      space="medium"
      rounded="small"
    >
      <.flex direction="col" align="stretch" gap="medium" class="w-full">
        <.text_field
          id={"#{@id_prefix}-q"}
          name="q"
          value={@filters.q}
          label="Search"
          placeholder="Title or description"
          size="medium"
          rounded="small"
          color="natural"
        />
        <.native_select
          id={"#{@id_prefix}-category"}
          name="category_id"
          label="Category"
          size="medium"
          rounded="small"
          color="natural"
        >
          <:option value="">Any</:option>
          <.select_option_group
            :for={group <- @category_groups}
            :if={group.children != []}
            id={"#{@id_prefix}-#{group.parent.slug}"}
            label={group.parent.name}
          >
            <:option value={group.parent.id} selected={category_selected?(@filters, group.parent)}>
              All {group.parent.name}
            </:option>
            <:option
              :for={child <- group.children}
              value={child.id}
              selected={category_selected?(@filters, child)}
            >
              {child.name}
            </:option>
          </.select_option_group>
          <:option
            :for={group <- @category_groups}
            :if={group.children == []}
            value={group.parent.id}
            selected={category_selected?(@filters, group.parent)}
          >
            {group.parent.name}
          </:option>
        </.native_select>
        <.native_select
          id={"#{@id_prefix}-kind"}
          name="kind"
          label="How it sells"
          size="medium"
          rounded="small"
          color="natural"
        >
          <:option value="">Any</:option>
          <:option value="stock" selected={@filters.kind == "stock"}>In stock</:option>
          <:option value="custom" selected={@filters.kind == "custom"}>Custom build</:option>
        </.native_select>
        <.number_field
          id={"#{@id_prefix}-min"}
          name="min_price"
          value={@filters.min_price}
          label="Min price (A$)"
          size="medium"
          rounded="small"
          color="natural"
        />
        <.number_field
          id={"#{@id_prefix}-max"}
          name="max_price"
          value={@filters.max_price}
          label="Max price (A$)"
          size="medium"
          rounded="small"
          color="natural"
        />
        <.checkbox_field
          id={"#{@id_prefix}-stock"}
          name="in_stock"
          value="on"
          checked={@filters.in_stock in ["true", "on", "1"]}
          label="In stock only"
          size="medium"
          color="natural"
        />
        <.number_field
          id={"#{@id_prefix}-lead"}
          name="max_lead_days"
          value={@filters.max_lead_days}
          label="Max lead time (days)"
          size="medium"
          rounded="small"
          color="natural"
        />
        <.native_select
          id={"#{@id_prefix}-sort"}
          name="sort"
          label="Sort"
          size="medium"
          rounded="small"
          color="natural"
        >
          <:option value="newest" selected={@filters.sort in [nil, "", "newest"]}>Newest</:option>
          <:option value="price_asc" selected={@filters.sort == "price_asc"}>
            Price low to high
          </:option>
          <:option value="price_desc" selected={@filters.sort == "price_desc"}>
            Price high to low
          </:option>
        </.native_select>
        <.button type="submit" variant="default" color="dark" size="medium" rounded="small">
          Apply
        </.button>
      </.flex>
    </.form_wrapper>
    """
  end

  defp category_selected?(filters, category) do
    to_string(filters.category_id) == to_string(category.id)
  end

  defp filters_from(params) do
    %{
      q: present(params["q"]),
      category_id: present(params["category_id"]),
      kind: present(params["kind"]),
      min_price: present(params["min_price"]),
      max_price: present(params["max_price"]),
      in_stock: present(params["in_stock"]),
      max_lead_days: present(params["max_lead_days"]),
      sort: present(params["sort"]) || "newest"
    }
  end

  defp empty_filters do
    %{
      q: "",
      category_id: "",
      kind: "",
      min_price: "",
      max_price: "",
      in_stock: "",
      max_lead_days: "",
      sort: "newest"
    }
  end

  defp browse_path(filters, page) do
    query =
      %{
        "q" => filters.q,
        "category_id" => filters.category_id,
        "kind" => filters.kind,
        "min_price" => filters.min_price,
        "max_price" => filters.max_price,
        "in_stock" => filters.in_stock,
        "max_lead_days" => filters.max_lead_days,
        "sort" => filters.sort,
        "page" => page
      }
      |> Enum.reject(fn {_key, value} -> value in [nil, ""] end)

    ~p"/browse?#{query}"
  end

  defp present(value) when is_binary(value) do
    case String.trim(value) do
      "" -> ""
      trimmed -> trimmed
    end
  end

  defp present(_), do: ""

  defp positive(value, fallback) do
    case Integer.parse(to_string(value || "")) do
      {page, ""} when page > 0 -> page
      _ -> fallback
    end
  end
end
