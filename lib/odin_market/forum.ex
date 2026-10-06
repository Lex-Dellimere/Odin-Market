defmodule OdinMarket.Forum do
  use Ash.Domain, otp_app: :odin_market, extensions: [AshAdmin.Domain]

  require Ash.Query

  alias OdinMarket.Forum.Board
  alias OdinMarket.Forum.Post
  alias OdinMarket.Forum.Thread

  admin do
    show? true
  end

  resources do
    resource Board
    resource Thread
    resource Post
  end

  def list_boards do
    Board
    |> Ash.Query.sort(position: :asc)
    |> Ash.read!(authorize?: false)
  end

  def get_board(slug) do
    Board
    |> Ash.Query.filter(slug == ^slug)
    |> Ash.read_one(authorize?: false)
  end

  def list_threads(board) do
    Thread
    |> Ash.Query.filter(board_id == ^board.id)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.load(:author)
    |> Ash.read!(authorize?: false)
  end

  def get_thread(id) do
    case Ecto.UUID.cast(to_string(id)) do
      {:ok, uuid} ->
        Thread
        |> Ash.Query.filter(id == ^uuid)
        |> Ash.Query.load([:author, :board, posts: :author])
        |> Ash.read_one(authorize?: false)

      _ ->
        {:ok, nil}
    end
  end

  def open_thread(board, actor, title, body) do
    Ash.create(Thread, %{title: title, board_id: board.id, body: body},
      action: :open,
      actor: actor
    )
  end

  def reply(thread, actor, body) do
    Ash.create(Post, %{thread_id: thread.id, body: body}, action: :reply, actor: actor)
  end

  def delete_post(post, actor) do
    if post.opening do
      case Ash.get(Thread, post.thread_id, authorize?: false) do
        {:ok, thread} -> Ash.destroy(thread, actor: actor)
        other -> other
      end
    else
      Ash.destroy(post, actor: actor)
    end
  end

  def author_name(%{username: username}) when not is_nil(username), do: to_string(username)
  def author_name(%{display_name: name}) when is_binary(name) and name != "", do: name
  def author_name(_), do: "Member"
end
