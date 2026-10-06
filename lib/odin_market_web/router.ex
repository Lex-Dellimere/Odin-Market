defmodule OdinMarketWeb.Router do
  use OdinMarketWeb, :router

  use AshAuthentication.Phoenix.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {OdinMarketWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
  end

  pipeline :webhook do
    plug :accepts, ["json"]
  end

  pipeline :ash_actor do
    plug OdinMarketWeb.Plugs.SetAshActor
  end

  pipeline :require_authenticated_user do
    plug OdinMarketWeb.Plugs.RequireAccess, :authenticated
  end

  pipeline :require_vendor do
    plug OdinMarketWeb.Plugs.RequireAccess, :vendor
  end

  pipeline :require_staff do
    plug OdinMarketWeb.Plugs.RequireAccess, :staff
  end

  scope "/", OdinMarketWeb do
    pipe_through :webhook

    post "/webhooks/stripe", StripeWebhookController, :create
  end

  scope "/", OdinMarketWeb do
    pipe_through :browser

    ash_authentication_live_session :public,
      on_mount: [{OdinMarketWeb.LiveUserAuth, :live_user_optional}] do
      live "/", HomeLive
      live "/browse", BrowseLive
      live "/privacy", PageLive, :privacy
      live "/terms", PageLive, :terms
      live "/l/:slug", ListingLive
      live "/shop/:slug", ShopLive
      live "/forum", ForumLive, :index
      live "/forum/:board", ForumLive, :board
      live "/forum/:board/:thread_id", ForumLive, :thread
      live "/vendor/pricing", VendorPricingLive
    end

    scope "/" do
      pipe_through :require_authenticated_user

      get "/account", RedirectController, :account
      get "/orders", RedirectController, :orders
      get "/orders/:id", RedirectController, :order
      get "/vendor", RedirectController, :vendor
      get "/vendor/shop", RedirectController, :shop
      get "/vendor/orders", RedirectController, :sales
      get "/vendor/orders/:id", RedirectController, :sale
      get "/vendor/listings", RedirectController, :listings
      get "/vendor/listings/new", RedirectController, :new_listing
      get "/vendor/listings/:id/edit", RedirectController, :edit_listing

      ash_authentication_live_session :authenticated,
        on_mount: [{OdinMarketWeb.LiveUserAuth, :live_user_required}] do
        live "/inbox", InboxLive, :index
        live "/inbox/:id", InboxLive, :thread
        live "/cart", CartLive
        live "/dashboard", DashboardLive
        live "/dashboard/orders", OrderLive, :index
        live "/dashboard/orders/:id", OrderLive, :show
        live "/dashboard/billing", AccountLive, :billing
        live "/dashboard/settings", AccountLive, :settings
        live "/checkout/success", CheckoutLive, :success
        live "/checkout/cancel", CheckoutLive, :cancel
        live "/checkout/:listing_id", CheckoutLive, :new
      end
    end

    scope "/" do
      pipe_through [:require_authenticated_user, :require_vendor]

      ash_authentication_live_session :vendor,
        on_mount: [
          {OdinMarketWeb.LiveUserAuth, :live_user_required},
          {OdinMarketWeb.LiveUserAuth, :live_vendor_required}
        ] do
        live "/dashboard/listings", VendorDashboardLive
        live "/dashboard/listings/new", VendorListingLive, :new
        live "/dashboard/listings/:id/edit", VendorListingLive, :edit
        live "/dashboard/sales", VendorOrderLive, :index
        live "/dashboard/sales/:id", VendorOrderLive, :show
        live "/dashboard/shop", VendorShopLive
      end
    end

    scope "/" do
      pipe_through [:require_authenticated_user, :require_staff]

      ash_authentication_live_session :staff,
        on_mount: [
          {OdinMarketWeb.LiveUserAuth, :live_user_required},
          {OdinMarketWeb.LiveUserAuth, :live_staff_required}
        ] do
        live "/staff", StaffLive, :desk
        live "/staff/reports", StaffLive, :reports
        live "/staff/reports/:id", StaffLive, :report
        live "/staff/people", StaffLive, :people
      end
    end

    auth_routes AuthController, OdinMarket.Accounts.User, path: "/auth"

    sign_out_route AuthController, "/sign-out",
      layout: {OdinMarketWeb.Layouts, :auth},
      overrides: [OdinMarketWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]

    sign_in_route register_path: "/register",
                  reset_path: "/reset",
                  auth_routes_prefix: "/auth",
                  layout: {OdinMarketWeb.Layouts, :auth},
                  on_mount: [{OdinMarketWeb.LiveUserAuth, :live_no_user}],
                  overrides: [
                    OdinMarketWeb.AuthOverrides,
                    AshAuthentication.Phoenix.Overrides.Default
                  ]

    reset_route auth_routes_prefix: "/auth",
                layout: {OdinMarketWeb.Layouts, :auth},
                overrides: [
                  OdinMarketWeb.AuthOverrides,
                  AshAuthentication.Phoenix.Overrides.Default
                ]

    confirm_route OdinMarket.Accounts.User, :confirm_new_user,
      auth_routes_prefix: "/auth",
      layout: {OdinMarketWeb.Layouts, :auth},
      overrides: [OdinMarketWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]
  end

  if Application.compile_env(:odin_market, :dev_routes) do
    import Phoenix.LiveDashboard.Router
    import AshAdmin.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: OdinMarketWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end

    scope "/admin" do
      pipe_through [:browser, :ash_actor]

      ash_admin "/"
    end
  end
end
