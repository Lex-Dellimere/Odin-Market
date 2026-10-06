defmodule OdinMarketWeb.CacheBodyReader do
  def read_body(conn, opts) do
    case Plug.Conn.read_body(conn, opts) do
      {:ok, body, conn} -> {:ok, body, stash(conn, body)}
      {:more, body, conn} -> {:more, body, stash(conn, body)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp stash(conn, chunk) do
    Plug.Conn.assign(conn, :raw_body, (conn.assigns[:raw_body] || "") <> chunk)
  end
end
