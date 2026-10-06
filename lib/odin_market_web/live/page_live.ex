defmodule OdinMarketWeb.PageLive do
  use OdinMarketWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    title = if socket.assigns.live_action == :privacy, do: "Privacy", else: "Terms"
    {:ok, assign(socket, page_title: title)}
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
      <.flex
        :if={@live_action == :privacy}
        id="privacy"
        direction="col"
        gap="gap-5"
        class="mx-auto w-full max-w-[68ch]"
      >
        <h1>Privacy</h1>
        <p>
          Odin Market stores the account, username, shop, listing, order, forum post, and message details needed to run an embedded-electronics marketplace.
        </p>
        <p>
          Shipping addresses are saved on your account and copied onto an order when you check out.
        </p>
        <p>
          Card numbers are entered on Stripe. Odin Market keeps the brand, last four digits, and expiry so you can recognize a saved card and remove it.
        </p>
        <p>
          We do not sell personal information. Shops see the buyer name, shipping address, and order notes for orders placed with them.
        </p>
        <p>
          Deleting an account removes the cart and saved cards, archives that shop's listings, frees the username, and replaces the name with “Deleted account”. Open orders have to finish first. Completed orders stay so the other person still has a record. A Vendor subscription is billed by Stripe and is not stored as a card number here.
        </p>
        <p>
          A report stores who sent it, what it is about, a short excerpt, and the reason. Staff actions are logged with the staff account, the action, and the time. That log stays after the content is removed.
        </p>
      </.flex>

      <.flex
        :if={@live_action == :terms}
        id="terms"
        direction="col"
        gap="gap-5"
        class="mx-auto w-full max-w-[68ch]"
      >
        <h1>Terms</h1>
        <p>
          Odin is a market for embedded electronics. Anyone can search and buy. A Vendor subscription is what lets an account list boards, modules, and custom hardware.
        </p>
        <p>
          A shop sets the price, the shipping fee, and the stock. A shipping fee of zero means the shop ships that part for free.
        </p>
        <p>
          Part prices are in Australian dollars. Payment is collected by Stripe. An order is paid when Stripe confirms it. If the part sells out before that confirmation, the order is cancelled and the charge is refunded from the Stripe dashboard. Vendor is A$25 a month, A$70 every 3 months, or A$240 a year. GST is not collected yet.
        </p>
        <p>
          Buyers can message a shop about a listing. Keep messages about the part and the order.
        </p>
        <p>
          The forum is for ideas, help, builds, and parts. Do not post spam, harassment, scams, illegal content, or someone else's private messages.
        </p>
        <p>
          A signed-in member can report a forum post, a chat message, or a listing. Forum reports are read by a forum moderator and an admin. Message and listing reports are read by a vendor moderator and an admin. Members cannot read the report queue.
        </p>
        <p>
          Staff can remove a forum post or thread, remove a reported message, archive a listing, or put a shop on hold. A shop on hold is hidden and cannot sell until the hold is released. A forum moderator does not read private chats. A vendor moderator does not appoint staff or close accounts.
        </p>
        <p id="terms-revocation">
          An admin can revoke an account. Revocation signs that person out, closes the account, and closes the shop. Odin does not refund a Vendor subscription or a completed part purchase because an account was revoked. Open orders stay on record and are not refunded automatically. Charges that Stripe has already confirmed are not reversed from this page.
        </p>
        <p>
          Creating an account means you agree to these terms, including revocation with no refund. The current version is {OdinMarket.Policy.version()}.
        </p>
        <p>
          These are the default rules for this marketplace until a shop and a buyer agree otherwise in the order notes.
        </p>
      </.flex>
    </.market_layout>
    """
  end
end
