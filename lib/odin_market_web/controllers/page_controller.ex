defmodule OdinMarketWeb.PageController do
  use OdinMarketWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
