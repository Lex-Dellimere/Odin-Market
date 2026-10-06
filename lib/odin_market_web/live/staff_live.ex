defmodule OdinMarketWeb.StaffLive do
  use OdinMarketWeb, :live_view

  alias OdinMarket.Moderation

  @roles [
    {"member", "Member"},
    {"forum_moderator", "Forum moderator"},
    {"vendor_moderator", "Vendor moderator"},
    {"admin", "Admin"}
  ]

  @role_atoms %{
    "member" => :member,
    "forum_moderator" => :forum_moderator,
    "vendor_moderator" => :vendor_moderator,
    "admin" => :admin
  }

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Desk")
     |> assign(:reports, [])
     |> assign(:audits, [])
     |> assign(:report, nil)
     |> assign(:shop, nil)
     |> assign(:person, nil)
     |> assign(:pending, nil)
     |> assign(:missing, false)
     |> assign(:lookup, to_form(%{"username" => ""}, as: :lookup))
     |> assign(:roles, @roles)
     |> assign(:role_atoms, @role_atoms)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    if socket.assigns.live_action == :people and socket.assigns.current_user.role != :admin do
      {:noreply, push_navigate(socket, to: ~p"/staff")}
    else
      {:noreply, load(socket, params)}
    end
  end

  @impl true
  def handle_event("dismiss", %{"id" => id}, socket) do
    case Moderation.dismiss(socket.assigns.current_user, id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Report dismissed.")
         |> push_navigate(to: ~p"/staff/reports")}

      _ ->
        {:noreply, put_flash(socket, :error, "That report could not be dismissed.")}
    end
  end

  def handle_event("remove", %{"id" => id}, socket) do
    case Moderation.remove_target(socket.assigns.current_user, id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Removed.")
         |> push_navigate(to: ~p"/staff/reports")}

      {:error, :unsupported} ->
        {:noreply, put_flash(socket, :error, "Use revoke or a shop hold for this report.")}

      _ ->
        {:noreply, put_flash(socket, :error, "That could not be removed.")}
    end
  end

  def handle_event("hold", %{"id" => user_id}, socket) do
    finish_shop(
      socket,
      Moderation.hold_shop(socket.assigns.current_user, user_id),
      "Shop placed on hold."
    )
  end

  def handle_event("release", %{"id" => user_id}, socket) do
    finish_shop(
      socket,
      Moderation.release_shop(socket.assigns.current_user, user_id),
      "Hold released."
    )
  end

  def handle_event("ask-revoke", _params, socket) do
    {:noreply, assign(socket, :pending, "revoke")}
  end

  def handle_event("revoke", %{"id" => id}, socket) do
    case Moderation.revoke(socket.assigns.current_user, id, "revoked from the desk") do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Account revoked. No refund was issued.")
         |> push_navigate(to: ~p"/staff")}

      {:error, message} when is_binary(message) ->
        {:noreply, put_flash(socket, :error, message)}

      _ ->
        {:noreply, put_flash(socket, :error, "That account could not be revoked.")}
    end
  end

  def handle_event("lookup", %{"lookup" => %{"username" => username}}, socket) do
    case Moderation.lookup(socket.assigns.current_user, username) do
      {:ok, person} ->
        {:noreply, assign(socket, person: person, pending: nil)}

      _ ->
        {:noreply,
         socket
         |> assign(:person, nil)
         |> put_flash(:error, "No account with that username.")}
    end
  end

  def handle_event("choose-role", %{"role" => role}, socket) do
    if Map.has_key?(@role_atoms, role) do
      {:noreply, assign(socket, :pending, role)}
    else
      {:noreply, put_flash(socket, :error, "That role is not available.")}
    end
  end

  def handle_event("confirm-role", %{"id" => id, "role" => role}, socket) do
    case Map.fetch(@role_atoms, role) do
      {:ok, atom} ->
        case Moderation.set_role(socket.assigns.current_user, id, atom) do
          {:ok, user} ->
            {:noreply,
             socket
             |> put_flash(:info, "Role updated.")
             |> assign(:person, person(user))
             |> assign(:pending, nil)}

          {:error, message} when is_binary(message) ->
            {:noreply, put_flash(socket, :error, message)}

          _ ->
            {:noreply, put_flash(socket, :error, "That role could not be changed.")}
        end

      :error ->
        {:noreply, put_flash(socket, :error, "That role is not available.")}
    end
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  defp load(socket, params) do
    actor = socket.assigns.current_user

    socket =
      socket
      |> assign(:reports, Moderation.list_reports(actor))
      |> assign(:audits, Moderation.list_audits(actor))
      |> assign(:pending, nil)

    case socket.assigns.live_action do
      :report ->
        load_report(socket, params["id"])

      :reports ->
        assign(socket, :page_title, "Reports")

      :people ->
        assign(socket, :page_title, "People")

      _ ->
        assign(socket, :page_title, "Desk")
    end
  end

  defp load_report(socket, id) do
    actor = socket.assigns.current_user

    case Moderation.get_report(actor, id) do
      {:ok, report} ->
        shop =
          case Moderation.shop_summary(actor, report.subject_id) do
            {:ok, summary} -> summary
            _ -> nil
          end

        socket
        |> assign(:missing, false)
        |> assign(:report, report)
        |> assign(:shop, shop)
        |> assign(:page_title, "Report")

      _ ->
        socket
        |> assign(:missing, true)
        |> assign(:report, nil)
        |> assign(:shop, nil)
        |> assign(:page_title, "Report")
    end
  end

  defp finish_shop(socket, :ok, message) do
    {:noreply,
     socket
     |> put_flash(:info, message)
     |> load_report(socket.assigns.report && socket.assigns.report.id)}
  end

  defp finish_shop(socket, {:error, :no_shop}, _message) do
    {:noreply, put_flash(socket, :error, "That account has no shop.")}
  end

  defp finish_shop(socket, _other, _message) do
    {:noreply, put_flash(socket, :error, "The shop could not be updated.")}
  end

  defp person(user) do
    %{
      id: user.id,
      username: to_string(user.username),
      display_name: user.display_name,
      role: user.role,
      selling: user.selling,
      deleted: not is_nil(user.deleted_at)
    }
  end

  defp role_label(role) do
    Enum.find_value(@roles, "Member", fn {key, label} ->
      if key == Atom.to_string(role), do: label
    end)
  end

  defp action_label(action) do
    case action do
      :delete_post -> "Removed a post"
      :delete_thread -> "Removed a thread"
      :delete_message -> "Removed a message"
      :archive_listing -> "Archived a listing"
      :hold_shop -> "Held a shop"
      :release_shop -> "Released a shop"
      :dismiss_report -> "Dismissed a report"
      :revoke_account -> "Revoked an account"
      :set_role -> "Changed a role"
      _ -> "Staff action"
    end
  end

  defp target_label(type) do
    case type do
      :forum_post -> "Forum post"
      :forum_thread -> "Forum thread"
      :message -> "Message"
      :listing -> "Listing"
      :user -> "Account"
      _ -> "Report"
    end
  end

  defp reason_label(reason) do
    case reason do
      :spam -> "Spam"
      :harassment -> "Harassment"
      :scam -> "Scam"
      :off_topic -> "Off topic"
      _ -> "Other"
    end
  end

  defp when_text(nil), do: ""

  defp when_text(datetime) do
    Calendar.strftime(datetime, "%d %b %Y")
  end

  defp remove_label(%{target_type: :message}), do: "Remove message"
  defp remove_label(%{target_type: :listing}), do: "Archive listing"
  defp remove_label(%{target_type: :forum_thread}), do: "Remove thread"
  defp remove_label(_report), do: "Remove post"

  defp removable?(%{target_type: type})
       when type in [:forum_post, :forum_thread, :message, :listing],
       do: true

  defp removable?(_report), do: false

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
      <.flex id="staff-desk" direction="col" gap="medium" class="w-full">
        <h1>{@page_title}</h1>
        <.flex id="staff-links" align="center" gap="small" class="flex-wrap">
          <.button_link
            id="staff-desk-link"
            navigate={~p"/staff"}
            variant={if(@live_action == :desk, do: "default", else: "outline")}
            color={if(@live_action == :desk, do: "dark", else: "natural")}
            size="medium"
            rounded="small"
          >
            Desk
          </.button_link>
          <.button_link
            id="staff-reports-link"
            navigate={~p"/staff/reports"}
            variant={if(@live_action in [:reports, :report], do: "default", else: "outline")}
            color={if(@live_action in [:reports, :report], do: "dark", else: "natural")}
            size="medium"
            rounded="small"
          >
            Reports
          </.button_link>
          <.button_link
            :if={@current_user.role == :admin}
            id="staff-people-link"
            navigate={~p"/staff/people"}
            variant={if(@live_action == :people, do: "default", else: "outline")}
            color={if(@live_action == :people, do: "dark", else: "natural")}
            size="medium"
            rounded="small"
          >
            People
          </.button_link>
        </.flex>

        <%= cond do %>
          <% @live_action == :desk -> %>
            <p>{role_label(@current_user.role)}. {length(@reports)} open reports in this desk.</p>
            <.card
              id="staff-audits"
              variant="base"
              color="natural"
              rounded="small"
              padding="medium"
              space="medium"
            >
              <p>Recent actions</p>
              <p :if={@audits == []}>No staff actions yet.</p>
              <p :for={entry <- @audits} id={"audit-#{entry.id}"}>
                {action_label(entry.action)} · {when_text(entry.inserted_at)}
              </p>
            </.card>
          <% @live_action == :reports -> %>
            <p :if={@reports == []} id="reports-empty">No open reports.</p>
            <.card
              :for={report <- @reports}
              id={"report-#{report.id}"}
              variant="base"
              color="natural"
              rounded="small"
              padding="medium"
              space="medium"
            >
              <p>{target_label(report.target_type)} · {reason_label(report.reason)}</p>
              <p>{report.excerpt}</p>
              <.button_link
                id={"open-report-#{report.id}"}
                navigate={~p"/staff/reports/#{report.id}"}
                variant="outline"
                color="natural"
                size="small"
                rounded="small"
                class="self-start"
              >
                Open
              </.button_link>
            </.card>
          <% @live_action == :report and @missing -> %>
            <.alert id="not-found" kind={:danger} title="Not found">
              That report is not in this desk.
            </.alert>
          <% @live_action == :report and @report -> %>
            <.card
              id="staff-report"
              variant="base"
              color="natural"
              rounded="small"
              padding="medium"
              space="medium"
            >
              <.flex direction="col" gap="small">
                <p>{target_label(@report.target_type)} · {reason_label(@report.reason)}</p>
                <p>From {@report.reporter_name} · about {@report.subject_name || "Member"}</p>
                <p :if={@report.note}>{@report.note}</p>
                <p class="whitespace-pre-wrap">{@report.excerpt}</p>
                <p :if={@report.status != :open}>Status: {@report.status}</p>
                <.flex :if={@shop} id="staff-shop" direction="col" gap="small">
                  <p>
                    Shop {@shop.shop_name}{if(@shop.held, do: " is on hold.", else: " is open.")}
                  </p>
                </.flex>
                <.flex
                  :if={@report.status == :open}
                  align="center"
                  gap="small"
                  class="flex-wrap"
                >
                  <.button
                    id="dismiss-report"
                    type="button"
                    variant="outline"
                    color="natural"
                    size="medium"
                    rounded="small"
                    phx-click="dismiss"
                    phx-value-id={@report.id}
                  >
                    Dismiss
                  </.button>
                  <.button
                    :if={removable?(@report)}
                    id="remove-target"
                    type="button"
                    variant="outline"
                    color="danger"
                    size="medium"
                    rounded="small"
                    phx-click="remove"
                    phx-value-id={@report.id}
                  >
                    {remove_label(@report)}
                  </.button>
                  <.button
                    :if={@shop && not @shop.held && @current_user.role in [:admin, :vendor_moderator]}
                    id="hold-shop"
                    type="button"
                    variant="outline"
                    color="danger"
                    size="medium"
                    rounded="small"
                    phx-click="hold"
                    phx-value-id={@report.subject_id}
                  >
                    Hold shop
                  </.button>
                  <.button
                    :if={@shop && @shop.held && @current_user.role in [:admin, :vendor_moderator]}
                    id="release-shop"
                    type="button"
                    variant="outline"
                    color="natural"
                    size="medium"
                    rounded="small"
                    phx-click="release"
                    phx-value-id={@report.subject_id}
                  >
                    Release shop
                  </.button>
                  <.button
                    :if={@current_user.role == :admin && @report.subject_id}
                    id="ask-revoke"
                    type="button"
                    variant="outline"
                    color="danger"
                    size="medium"
                    rounded="small"
                    phx-click="ask-revoke"
                  >
                    Revoke account
                  </.button>
                  <.button
                    :if={@pending == "revoke" && @report.subject_id}
                    id="revoke-confirm"
                    type="button"
                    variant="default"
                    color="danger"
                    size="medium"
                    rounded="small"
                    phx-click="revoke"
                    phx-value-id={@report.subject_id}
                  >
                    Confirm revoke, no refund
                  </.button>
                </.flex>
              </.flex>
            </.card>
          <% @live_action == :people -> %>
            <.form_wrapper
              for={@lookup}
              id="staff-lookup"
              phx-submit="lookup"
              variant="transparent"
              space="medium"
              rounded="small"
            >
              <.text_field
                field={@lookup[:username]}
                label="Username"
                size="medium"
                rounded="small"
                color="natural"
              />
              <.button type="submit" variant="default" color="dark" size="medium" rounded="small">
                Look up
              </.button>
            </.form_wrapper>
            <.card
              :if={@person}
              id="staff-person"
              variant="base"
              color="natural"
              rounded="small"
              padding="medium"
              space="medium"
            >
              <.flex direction="col" gap="small">
                <p>{@person.username}</p>
                <p>{@person.display_name}</p>
                <p>{role_label(@person.role)}</p>
                <p :if={@person.deleted}>This account is closed.</p>
                <.flex
                  :if={not @person.deleted and @person.id != @current_user.id}
                  align="center"
                  gap="small"
                  class="flex-wrap"
                >
                  <%= for {role, label} <- @roles, role != Atom.to_string(@person.role) do %>
                    <.button
                      id={"role-#{role}"}
                      type="button"
                      variant="outline"
                      color="natural"
                      size="small"
                      rounded="small"
                      phx-click="choose-role"
                      phx-value-role={role}
                    >
                      {label}
                    </.button>
                  <% end %>
                  <.button
                    :if={@pending && @pending != "revoke"}
                    id="confirm-role"
                    type="button"
                    variant="default"
                    color="dark"
                    size="medium"
                    rounded="small"
                    phx-click="confirm-role"
                    phx-value-id={@person.id}
                    phx-value-role={@pending}
                  >
                    Confirm {role_label(Map.fetch!(@role_atoms, @pending))}
                  </.button>
                  <.button
                    :if={@person.role != :admin}
                    id="ask-revoke"
                    type="button"
                    variant="outline"
                    color="danger"
                    size="medium"
                    rounded="small"
                    phx-click="ask-revoke"
                  >
                    Revoke account
                  </.button>
                  <.button
                    :if={@pending == "revoke"}
                    id="revoke-confirm"
                    type="button"
                    variant="default"
                    color="danger"
                    size="medium"
                    rounded="small"
                    phx-click="revoke"
                    phx-value-id={@person.id}
                  >
                    Confirm revoke, no refund
                  </.button>
                </.flex>
              </.flex>
            </.card>
          <% true -> %>
        <% end %>
      </.flex>
    </.market_layout>
    """
  end
end
