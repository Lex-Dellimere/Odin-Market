defmodule OdinMarket.Chat do
  use Ash.Domain, otp_app: :odin_market, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource OdinMarket.Chat.Conversation
    resource OdinMarket.Chat.Message
  end
end
