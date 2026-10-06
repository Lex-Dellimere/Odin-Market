defmodule OdinMarketWeb.StripeWebhookController do
  use OdinMarketWeb, :controller

  def create(conn, _params) do
    payload = conn.assigns[:raw_body] || ""
    signature = conn |> get_req_header("stripe-signature") |> List.first()

    case OdinMarket.Payments.handle_webhook(payload, signature) do
      :ok -> send_resp(conn, 200, "")
      {:error, :bad_signature} -> send_resp(conn, 400, "")
      {:error, _} -> send_resp(conn, 500, "")
    end
  end
end
