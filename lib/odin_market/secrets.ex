defmodule OdinMarket.Secrets do
  use AshAuthentication.Secret

  def secret_for(
        [:authentication, :tokens, :signing_secret],
        OdinMarket.Accounts.User,
        _opts,
        _context
      ) do
    Application.fetch_env(:odin_market, :token_signing_secret)
  end
end
