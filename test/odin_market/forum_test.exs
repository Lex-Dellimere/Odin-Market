defmodule OdinMarket.ForumTest do
  use OdinMarket.DataCase, async: true

  alias OdinMarket.Forum
  alias OdinMarket.Forum.Post
  alias OdinMarket.Forum.Thread

  test "boards are public and posting requires an account" do
    boards = Forum.list_boards()
    assert Enum.map(boards, & &1.slug) == ["ideas", "help", "show-your-work", "parts-and-tools"]

    {:ok, board} = Forum.get_board("help")
    guest = register_user(%{display_name: "Guest"})

    assert {:error, %Ash.Error.Forbidden{}} =
             Ash.create(Thread, %{title: "No actor", board_id: board.id, body: "Hello"},
               action: :open,
               authorize?: true
             )

    assert {:ok, thread} =
             Forum.open_thread(board, guest, "Bring-up help", "The board stays dark.")

    assert length(Forum.list_threads(board)) == 1

    {:ok, loaded} = Forum.get_thread(thread.id)
    assert hd(loaded.posts).opening
    assert hd(loaded.posts).body == "The board stays dark."
  end

  test "the author can delete a reply and deleting the opening post removes the thread" do
    author = register_user(%{display_name: "Author"})
    other = register_user(%{display_name: "Other"})
    {:ok, board} = Forum.get_board("ideas")

    {:ok, thread} =
      Forum.open_thread(board, author, "A sensor idea", "Measure current on the rail.")

    {:ok, reply} = Forum.reply(thread, other, "Use a shunt.")

    assert {:error, %Ash.Error.Forbidden{}} = Forum.delete_post(reply, author)
    assert destroyed?(Forum.delete_post(reply, other))
    assert {:error, %Ash.Error.Invalid{}} = Ash.get(Post, reply.id, authorize?: false)

    {:ok, loaded} = Forum.get_thread(thread.id)
    opening = Enum.find(loaded.posts, & &1.opening)
    assert destroyed?(Forum.delete_post(opening, author))
    assert {:ok, nil} = Forum.get_thread(thread.id)
  end

  defp destroyed?(:ok), do: true
  defp destroyed?({:ok, _}), do: true
  defp destroyed?(_), do: false
end
