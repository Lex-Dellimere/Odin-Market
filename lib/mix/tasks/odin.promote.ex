defmodule Mix.Tasks.Odin.Promote do
  @moduledoc """
  Appoint a staff role from a username. Dev only.

      mix odin.promote ada admin
      mix odin.promote sam forum_moderator
      mix odin.promote riley vendor_moderator
  """

  use Mix.Task

  require Ash.Query

  @shortdoc "Appoint a dev staff role by username"

  @roles %{
    "member" => :member,
    "forum_moderator" => :forum_moderator,
    "vendor_moderator" => :vendor_moderator,
    "admin" => :admin
  }

  @impl true
  def run([username, role]) do
    if Mix.env() != :dev do
      Mix.raise("odin.promote only runs in dev")
    end

    case Map.fetch(@roles, role) do
      :error ->
        Mix.raise("role must be member, forum_moderator, vendor_moderator, or admin")

      {:ok, atom} ->
        endpoint = Application.get_env(:odin_market, OdinMarketWeb.Endpoint, [])

        Application.put_env(
          :odin_market,
          OdinMarketWeb.Endpoint,
          Keyword.put(endpoint, :server, false)
        )

        Mix.Task.run("app.start")
        promote(username, atom)
    end
  end

  def run(_args) do
    Mix.raise("usage: mix odin.promote USERNAME ROLE")
  end

  defp promote(username, role) do
    name = String.trim(username)

    case OdinMarket.Accounts.User
         |> Ash.Query.filter(username == ^name)
         |> Ash.read_one(authorize?: false) do
      {:ok, user} when not is_nil(user) ->
        case Ash.update(user, %{role: role}, action: :set_role, authorize?: false) do
          {:ok, updated} ->
            Mix.shell().info("#{updated.username} is now #{updated.role}")

          {:error, error} ->
            Mix.raise(Exception.message(error))
        end

      _ ->
        Mix.raise("no account with that username")
    end
  end
end
