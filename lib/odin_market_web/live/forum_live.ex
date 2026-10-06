defmodule OdinMarketWeb.ForumLive do
  use OdinMarketWeb, :live_view

  alias OdinMarket.Forum
  alias OdinMarket.Forum.Post
  alias OdinMarket.Forum.Thread

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Forum")
     |> assign(:boards, [])
     |> assign(:board, nil)
     |> assign(:threads, [])
     |> assign(:thread, nil)
     |> assign(:posts, [])
     |> assign(:missing, false)
     |> assign(:editing_id, nil)
     |> assign(:thread_form, nil)
     |> assign(:reply_form, nil)
     |> assign(:edit_form, nil)
     |> assign(:reporting_id, nil)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_event("open-thread", %{"thread" => params}, socket) do
    params = Map.put(params, "board_id", socket.assigns.board.id)

    case AshPhoenix.Form.submit(socket.assigns.thread_form, params: params) do
      {:ok, thread} ->
        {:noreply,
         push_navigate(socket, to: ~p"/forum/#{socket.assigns.board.slug}/#{thread.id}")}

      {:error, form} ->
        {:noreply, assign(socket, :thread_form, to_form(form))}
    end
  end

  def handle_event("reply", %{"post" => params}, socket) do
    params = Map.put(params, "thread_id", socket.assigns.thread.id)

    case AshPhoenix.Form.submit(socket.assigns.reply_form, params: params) do
      {:ok, _post} ->
        {:noreply, refresh_thread(socket)}

      {:error, form} ->
        {:noreply, assign(socket, :reply_form, to_form(form))}
    end
  end

  def handle_event("edit-post", %{"id" => id}, socket) do
    post = Enum.find(socket.assigns.posts, &(to_string(&1.id) == id))

    form =
      if post do
        post
        |> AshPhoenix.Form.for_update(:edit,
          domain: Forum,
          actor: socket.assigns.current_user,
          as: "post"
        )
        |> to_form()
      end

    {:noreply, socket |> assign(:editing_id, id) |> assign(:edit_form, form)}
  end

  def handle_event("cancel-edit", _params, socket) do
    {:noreply, socket |> assign(:editing_id, nil) |> assign(:edit_form, nil)}
  end

  def handle_event("save-post", %{"post" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.edit_form, params: params) do
      {:ok, _post} ->
        {:noreply, refresh_thread(socket)}

      {:error, form} ->
        {:noreply, assign(socket, :edit_form, to_form(form))}
    end
  end

  def handle_event("delete-post", %{"id" => id}, socket) do
    post = Enum.find(socket.assigns.posts, &(to_string(&1.id) == id))
    user = socket.assigns.current_user

    result =
      cond do
        is_nil(post) or is_nil(user) ->
          :error

        user.role in [:admin, :forum_moderator] ->
          OdinMarket.Moderation.delete_forum_post(user, post)

        true ->
          Forum.delete_post(post, user)
      end

    case result do
      :ok ->
        after_delete(socket, post)

      {:ok, _} ->
        after_delete(socket, post)

      _ ->
        {:noreply, put_flash(socket, :error, "That post could not be deleted.")}
    end
  end

  def handle_event("open-report", %{"id" => id}, socket) do
    {:noreply, assign(socket, :reporting_id, id)}
  end

  def handle_event("cancel-report", _params, socket) do
    {:noreply, assign(socket, :reporting_id, nil)}
  end

  def handle_event("file-report", %{"report" => params}, socket) do
    file_report(socket, :forum_post, params)
  end

  defp apply_action(socket, :index, _params) do
    assign(socket, :boards, Forum.list_boards())
  end

  defp apply_action(socket, :board, %{"board" => slug}) do
    case Forum.get_board(slug) do
      {:ok, board} when not is_nil(board) ->
        socket
        |> assign(:missing, false)
        |> assign(:board, board)
        |> assign(:threads, Forum.list_threads(board))
        |> assign(:thread_form, thread_form(socket.assigns.current_user))
        |> assign(:page_title, board.name)

      _ ->
        assign(socket, :missing, true)
    end
  end

  defp apply_action(socket, :thread, %{"board" => slug, "thread_id" => id}) do
    case Forum.get_thread(id) do
      {:ok, %{board: %{slug: board_slug}} = thread} when board_slug == slug ->
        socket
        |> assign(:missing, false)
        |> assign(:board, thread.board)
        |> assign(:thread, thread)
        |> assign(:posts, thread.posts)
        |> assign(:editing_id, nil)
        |> assign(:edit_form, nil)
        |> assign(:reply_form, reply_form(socket.assigns.current_user))
        |> assign(:reporting_id, nil)
        |> assign(:page_title, thread.title)

      _ ->
        assign(socket, :missing, true)
    end
  end

  defp thread_form(nil), do: nil

  defp thread_form(user) do
    Thread
    |> AshPhoenix.Form.for_create(:open, domain: Forum, actor: user, as: "thread")
    |> to_form()
  end

  defp reply_form(nil), do: nil

  defp reply_form(user) do
    Post
    |> AshPhoenix.Form.for_create(:reply, domain: Forum, actor: user, as: "post")
    |> to_form()
  end

  defp refresh_thread(socket) do
    case Forum.get_thread(socket.assigns.thread.id) do
      {:ok, thread} ->
        socket
        |> assign(:thread, thread)
        |> assign(:posts, thread.posts)
        |> assign(:editing_id, nil)
        |> assign(:edit_form, nil)
        |> assign(:reply_form, reply_form(socket.assigns.current_user))

      _ ->
        assign(socket, :missing, true)
    end
  end

  defp can_edit?(user, post) do
    user && post.author_id == user.id
  end

  defp can_delete?(user, post) do
    user && (user.role in [:admin, :forum_moderator] or post.author_id == user.id)
  end

  defp can_report?(user, post) do
    user && user.id != post.author_id
  end

  defp after_delete(socket, post) do
    if post.opening do
      {:noreply, push_navigate(socket, to: ~p"/forum/#{socket.assigns.board.slug}")}
    else
      {:noreply, refresh_thread(socket)}
    end
  end

  defp file_report(socket, type, params) do
    attrs = %{
      target_type: type,
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
  def render(assigns) do
    ~H"""
    <.market_layout
      flash={@flash}
      current_scope={@current_scope}
      nav_categories={@nav_categories}
      unread_count={@unread_count}
      nav_query={@nav_query}
    >
      <.flex direction="col" gap="gap-8" class="w-full">
        <.flex direction="col" gap="small">
          <h1>Forum</h1>
          <p>
            Embedded electronics. Ask for help, show a board, or talk through an idea before it is a product.
          </p>
        </.flex>

        <.alert :if={@missing} id="forum-missing" kind={:natural} title="Not found">
          That board or thread is gone.
        </.alert>

        <%= cond do %>
          <% @live_action == :index -> %>
            <.flex id="forum-boards" direction="col" gap="medium">
              <.card
                :for={board <- @boards}
                id={"board-#{board.slug}"}
                variant="base"
                color="natural"
                rounded="small"
                padding="medium"
                space="small"
              >
                <h2>
                  <.link
                    navigate={~p"/forum/#{board.slug}"}
                    class="font-semibold text-neutral-900 underline decoration-neutral-300 underline-offset-4 hover:decoration-neutral-900"
                  >
                    {board.name}
                  </.link>
                </h2>
                <p>{board.description}</p>
              </.card>
            </.flex>
          <% @live_action == :board and not @missing -> %>
            <.flex direction="col" gap="medium">
              <.button_link
                navigate={~p"/forum"}
                variant="outline"
                color="natural"
                size="small"
                rounded="small"
                class="self-start"
              >
                All boards
              </.button_link>
              <h2>{@board.name}</h2>
              <p>{@board.description}</p>
              <.alert :if={@threads == []} id="forum-empty" kind={:natural} title="No threads yet">
                Start one if you are signed in.
              </.alert>
              <.flex id="forum-threads" direction="col" gap="small">
                <.card
                  :for={thread <- @threads}
                  id={"thread-#{thread.id}"}
                  variant="base"
                  color="natural"
                  rounded="small"
                  padding="medium"
                  space="small"
                >
                  <h3>
                    <.link
                      navigate={~p"/forum/#{@board.slug}/#{thread.id}"}
                      class="font-semibold text-neutral-900 underline decoration-neutral-300 underline-offset-4 hover:decoration-neutral-900"
                    >
                      {thread.title}
                    </.link>
                  </h3>
                  <p>{Forum.author_name(thread.author)}</p>
                </.card>
              </.flex>
              <%= if @current_user do %>
                <.form_wrapper
                  for={@thread_form}
                  id="thread-form"
                  phx-submit="open-thread"
                  variant="transparent"
                  space="medium"
                  rounded="small"
                >
                  <.card
                    variant="base"
                    color="natural"
                    rounded="small"
                    padding="medium"
                    space="medium"
                  >
                    <h2>New thread</h2>
                    <.text_field
                      field={@thread_form[:title]}
                      label="Title"
                      size="medium"
                      rounded="small"
                      color="natural"
                    />
                    <.textarea_field
                      field={@thread_form[:body]}
                      label="Post"
                      rows="6"
                      size="medium"
                      rounded="small"
                      color="natural"
                    />
                    <.button
                      type="submit"
                      variant="default"
                      color="dark"
                      size="medium"
                      rounded="small"
                    >
                      Post thread
                    </.button>
                  </.card>
                </.form_wrapper>
              <% else %>
                <.button_link
                  id="forum-sign-in"
                  navigate={~p"/sign-in"}
                  variant="default"
                  color="dark"
                  size="medium"
                  rounded="small"
                  class="self-start"
                >
                  Sign in to post
                </.button_link>
              <% end %>
            </.flex>
          <% @live_action == :thread and not @missing -> %>
            <.flex direction="col" gap="medium">
              <.button_link
                navigate={~p"/forum/#{@board.slug}"}
                variant="outline"
                color="natural"
                size="small"
                rounded="small"
                class="self-start"
              >
                {@board.name}
              </.button_link>
              <h2>{@thread.title}</h2>
              <.flex id="forum-posts" direction="col" gap="medium">
                <.card
                  :for={post <- @posts}
                  id={"post-#{post.id}"}
                  variant="base"
                  color="natural"
                  rounded="small"
                  padding="medium"
                  space="medium"
                >
                  <p>{Forum.author_name(post.author)}</p>
                  <%= if @editing_id == to_string(post.id) do %>
                    <.form_wrapper
                      for={@edit_form}
                      id={"edit-post-#{post.id}"}
                      phx-submit="save-post"
                      variant="transparent"
                      space="small"
                      rounded="small"
                    >
                      <.textarea_field
                        field={@edit_form[:body]}
                        label="Post"
                        rows="5"
                        size="medium"
                        rounded="small"
                        color="natural"
                      />
                      <.flex align="center" gap="small">
                        <.button
                          type="submit"
                          variant="default"
                          color="dark"
                          size="small"
                          rounded="small"
                        >
                          Save
                        </.button>
                        <.button
                          type="button"
                          variant="outline"
                          color="natural"
                          size="small"
                          rounded="small"
                          phx-click="cancel-edit"
                        >
                          Cancel
                        </.button>
                      </.flex>
                    </.form_wrapper>
                  <% else %>
                    <p class="whitespace-pre-wrap">{post.body}</p>
                    <.flex
                      :if={
                        can_edit?(@current_user, post) or can_delete?(@current_user, post) or
                          can_report?(@current_user, post)
                      }
                      align="center"
                      gap="small"
                      class="flex-wrap"
                    >
                      <.button
                        :if={can_edit?(@current_user, post)}
                        id={"edit-post-#{post.id}"}
                        type="button"
                        variant="outline"
                        color="natural"
                        size="small"
                        rounded="small"
                        phx-click="edit-post"
                        phx-value-id={post.id}
                      >
                        Edit
                      </.button>
                      <.button
                        :if={can_delete?(@current_user, post)}
                        id={"delete-post-#{post.id}"}
                        type="button"
                        variant="outline"
                        color="natural"
                        size="small"
                        rounded="small"
                        phx-click="delete-post"
                        phx-value-id={post.id}
                      >
                        Delete
                      </.button>
                      <.report_box
                        :if={can_report?(@current_user, post)}
                        id={to_string(post.id)}
                        open?={@reporting_id == to_string(post.id)}
                      />
                    </.flex>
                  <% end %>
                </.card>
              </.flex>
              <%= if @current_user do %>
                <.form_wrapper
                  for={@reply_form}
                  id="reply-form"
                  phx-submit="reply"
                  variant="transparent"
                  space="medium"
                  rounded="small"
                >
                  <.textarea_field
                    field={@reply_form[:body]}
                    label="Reply"
                    rows="5"
                    size="medium"
                    rounded="small"
                    color="natural"
                  />
                  <.button type="submit" variant="default" color="dark" size="medium" rounded="small">
                    Reply
                  </.button>
                </.form_wrapper>
              <% else %>
                <.button_link
                  navigate={~p"/sign-in"}
                  variant="default"
                  color="dark"
                  size="medium"
                  rounded="small"
                  class="self-start"
                >
                  Sign in to reply
                </.button_link>
              <% end %>
            </.flex>
          <% true -> %>
        <% end %>
      </.flex>
    </.market_layout>
    """
  end
end
