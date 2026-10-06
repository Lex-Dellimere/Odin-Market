defmodule OdinMarketWeb.AuthComponents do
  use OdinMarketWeb, :html

  attr :form, :any, required: true

  def register_extra(assigns) do
    ~H"""
    <.flex direction="col" gap="small" class="w-full">
      <.text_field
        field={@form[:username]}
        label="Username"
        placeholder="Letters, numbers, underscores"
        size="medium"
        rounded="small"
        color="natural"
      />
      <.checkbox_field
        id="register-policy"
        field={@form[:policy_accepted]}
        value="true"
        label="I agree to the terms, including account closure with no refund"
        color="natural"
        size="medium"
        rounded="small"
      />
      <.button_link
        id="register-terms"
        navigate={~p"/terms"}
        variant="transparent"
        color="natural"
        size="small"
        rounded="small"
        class="self-start"
      >
        Read the terms
      </.button_link>
    </.flex>
    """
  end
end
