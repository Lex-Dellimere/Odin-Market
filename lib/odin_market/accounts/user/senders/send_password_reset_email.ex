defmodule OdinMarket.Accounts.User.Senders.SendPasswordResetEmail do
  @moduledoc """
  Sends a password reset email
  """

  use AshAuthentication.Sender
  use OdinMarketWeb, :verified_routes

  import Swoosh.Email

  alias OdinMarket.Mailer

  @impl true
  def send(user, token, _) do
    new()
    # replace with the real from address
    |> from({"noreply", "noreply@example.com"})
    |> to(to_string(user.email))
    |> subject("Reset your password")
    |> html_body(body(token: token))
    |> Mailer.deliver!()
  end

  defp body(params) do
    url = url(~p"/password-reset/#{params[:token]}")

    """
    <p>Click this link to reset your password:</p>
    <p><a href="#{url}">#{url}</a></p>
    """
  end
end
