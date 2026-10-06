defmodule OdinMarket.Repo.Migrations.Forum do
  use Ecto.Migration

  def up do
    create table(:forum_boards, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :name, :text, null: false
      add :slug, :text, null: false
      add :description, :text, null: false
      add :position, :integer, null: false, default: 0
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:forum_boards, [:slug])

    create table(:forum_threads, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :board_id, references(:forum_boards, type: :uuid, on_delete: :delete_all), null: false
      add :author_id, references(:users, type: :uuid, on_delete: :nilify_all)
      add :title, :text, null: false
      timestamps(type: :utc_datetime_usec)
    end

    create index(:forum_threads, [:board_id])

    create table(:forum_posts, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false

      add :thread_id, references(:forum_threads, type: :uuid, on_delete: :delete_all), null: false

      add :author_id, references(:users, type: :uuid, on_delete: :nilify_all)
      add :body, :text, null: false
      add :opening, :boolean, null: false, default: false
      timestamps(type: :utc_datetime_usec)
    end

    create index(:forum_posts, [:thread_id])

    flush()

    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    repo().insert_all("forum_boards", [
      board("Ideas", "ideas", "Show a direction before it is a product.", 1, now),
      board("Help", "help", "Stuck on a circuit, a part, or a bring-up.", 2, now),
      board("Show your work", "show-your-work", "What you built, and how it behaves.", 3, now),
      board(
        "Parts and tools",
        "parts-and-tools",
        "Ask which part fits, or which tool is worth it.",
        4,
        now
      )
    ])
  end

  def down do
    drop table(:forum_posts)
    drop table(:forum_threads)
    drop table(:forum_boards)
  end

  defp board(name, slug, description, position, now) do
    %{
      id: Ecto.UUID.bingenerate(),
      name: name,
      slug: slug,
      description: description,
      position: position,
      inserted_at: now,
      updated_at: now
    }
  end
end
