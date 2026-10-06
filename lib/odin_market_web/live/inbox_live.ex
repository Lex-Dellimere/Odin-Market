defmodule OdinMarketWeb.InboxLive do
  use OdinMarketWeb, :live_view

  alias OdinMarket.Errors
  alias OdinMarket.Messaging

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Inbox")
     |> assign(:conversations, [])
     |> assign(:conversation, nil)
     |> assign(:reporting_id, nil)
     |> stream(:messages, [])}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket =
      socket
      |> assign(:conversations, Messaging.inbox(socket.assigns.current_user))
      |> assign(:reporting_id, nil)

    socket =
      if socket.assigns.live_action == :thread do
        open_thread(socket, params["id"])
      else
        assign(socket, :conversation, nil)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("send", %{"message" => %{"body" => body}}, socket) do
    conversation = socket.assigns.conversation

    case Messaging.send(socket.assigns.current_user, conversation.id, body) do
      {:ok, _message} ->
        {:noreply, assign(socket, :composer, to_form(%{"body" => ""}, as: :message))}

      {:error, reason} when is_atom(reason) ->
        {:noreply, put_flash(socket, :error, Errors.message(reason))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, Errors.message(:blank))}
    end
  end

  def handle_event("open-report", %{"id" => id}, socket) do
    {:noreply, assign(socket, :reporting_id, id)}
  end

  def handle_event("cancel-report", _params, socket) do
    {:noreply, assign(socket, :reporting_id, nil)}
  end

  def handle_event("file-report", %{"report" => params}, socket) do
    attrs = %{
      target_type: :message,
      target_id: params["target_id"],
      reason: params["reason"],
      note: params["note"]
    }

    case OdinMarket.Moderation.file_report(socket.assigns.current_user, attrs) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:reporting_id, nil)
         |> put_flash(:info, "Report sent.")}

      {:error, message} when is_binary(message) ->
        {:noreply, put_flash(socket, :error, message)}

      _ ->
        {:noreply, put_flash(socket, :error, "That report could not be sent.")}
    end
  end

  @impl true
  def handle_info({:message, message}, socket) do
    if socket.assigns.conversation && message.conversation_id == socket.assigns.conversation.id do
      Messaging.mark_read(socket.assigns.conversation.id, socket.assigns.current_user.id)
      {:noreply, stream_insert(socket, :messages, message)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(:inbox, socket) do
    {:noreply, assign(socket, :conversations, Messaging.inbox(socket.assigns.current_user))}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

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
      <.flex direction="col" gap="medium">
        <h1>Inbox</h1>
        <.scroll_area id="inbox-list">
          <.alert :if={@conversations == []} id="inbox-empty" kind={:natural} title="No conversations">
            Message a seller from a listing.
          </.alert>
          <.flex direction="col" gap="medium">
            <.button_link
              :for={conversation <- @conversations}
              id={"conversation-#{conversation.id}"}
              navigate={~p"/inbox/#{conversation.id}"}
              variant="outline"
              color="natural"
              size="medium"
              rounded="small"
              class="w-full justify-start"
            >
              <.flex direction="col" align="start" gap="extra_small">
                <span>{conversation.listing && conversation.listing.title}</span>
                <span>{partner_name(conversation, @current_user)}</span>
              </.flex>
            </.button_link>
          </.flex>
        </.scroll_area>

        <.alert :if={@live_action == :index} kind={:natural} title="Pick a conversation">
          Choose a thread to read and reply.
        </.alert>
        <.alert
          :if={@live_action == :thread and is_nil(@conversation)}
          id="not-found"
          kind={:danger}
          title="Not found"
        >
          That conversation is not available.
        </.alert>

        <.card
          :if={@conversation}
          id="thread"
          variant="base"
          color="natural"
          rounded="small"
          padding="medium"
          space="medium"
        >
          <.flex direction="col" gap="medium">
            <h2>{@conversation.listing.title}</h2>
            <p>{partner_name(@conversation, @current_user)}</p>
            <.flex id="messages" direction="col" gap="medium" phx-update="stream">
              <div class="hidden only:block">No messages yet.</div>
              <div :for={{id, message} <- @streams.messages} id={id}>
                <.chat
                  id={"bubble-#{message.id}"}
                  position={if message.sender_id == @current_user.id, do: "flipped", else: "normal"}
                  color="natural"
                  rounded="small"
                  size="medium"
                  padding="medium"
                  space="medium"
                >
                  <.chat_section>
                    <p class="whitespace-pre-line">{message.body}</p>
                    <.report_box
                      :if={message.sender_id != @current_user.id}
                      id={to_string(message.id)}
                      open?={@reporting_id == to_string(message.id)}
                    />
                  </.chat_section>
                </.chat>
              </div>
            </.flex>
            <.form_wrapper
              for={@composer}
              id="message-form"
              phx-submit="send"
              variant="transparent"
              space="medium"
              rounded="small"
            >
              <.textarea_field
                field={@composer[:body]}
                label="Message"
                rows="3"
                size="medium"
                rounded="small"
                color="natural"
              />
              <.button type="submit" variant="default" color="dark" size="medium" rounded="small">
                Send
              </.button>
            </.form_wrapper>
          </.flex>
        </.card>
      </.flex>
    </.market_layout>
    """
  end

  defp open_thread(socket, id) do
    case Messaging.get_thread(socket.assigns.current_user, id) do
      {:ok, conversation} ->
        socket = subscribe_thread(socket, conversation.id)

        socket
        |> assign(:conversation, conversation)
        |> assign(:page_title, conversation.listing.title)
        |> assign(:composer, to_form(%{"body" => ""}, as: :message))
        |> stream(:messages, conversation.messages, reset: true)

      _ ->
        socket
        |> assign(:conversation, nil)
        |> stream(:messages, [], reset: true)
    end
  end

  defp subscribe_thread(socket, id) do
    if connected?(socket) && socket.assigns[:thread_topic] != id do
      if topic = socket.assigns[:thread_topic] do
        Phoenix.PubSub.unsubscribe(OdinMarket.PubSub, "chat:conv:#{topic}")
      end

      Phoenix.PubSub.subscribe(OdinMarket.PubSub, "chat:conv:#{id}")
      assign(socket, :thread_topic, id)
    else
      socket
    end
  end

  defp partner_name(conversation, %{id: user_id}) do
    cond do
      conversation.buyer_id == user_id && conversation.vendor ->
        conversation.vendor.shop_name

      conversation.buyer && conversation.buyer.display_name ->
        conversation.buyer.display_name

      true ->
        "Member"
    end
  end

  defp partner_name(_conversation, _user), do: "Member"
end
