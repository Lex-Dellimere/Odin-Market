defmodule OdinMarketWeb.AuthOverrides do
  use AshAuthentication.Phoenix.Overrides

  @button """
  w-full cursor-pointer rounded-md border border-neutral-900 bg-neutral-900 px-4 py-2.5 text-sm font-medium text-white hover:bg-neutral-700
  """
  @input """
  block w-full rounded-md border border-neutral-300 bg-white px-3 py-2 text-sm text-neutral-900
  """
  @input_error """
  block w-full rounded-md border border-red-600 bg-white px-3 py-2 text-sm text-neutral-900
  """
  @label "mb-1 block text-sm font-medium text-neutral-800"
  @heading "mb-4 text-2xl font-semibold tracking-tight text-neutral-900"

  override AshAuthentication.Phoenix.SignInLive do
    set :root_class, "w-full"
  end

  override AshAuthentication.Phoenix.SignOutLive do
    set :root_class, "w-full"
  end

  override AshAuthentication.Phoenix.ResetLive do
    set :root_class, "w-full"
  end

  override AshAuthentication.Phoenix.ConfirmLive do
    set :root_class, "w-full"
  end

  override AshAuthentication.Phoenix.Components.Banner do
    set :image_url, nil
    set :dark_image_url, nil
  end

  override AshAuthentication.Phoenix.Components.SignIn do
    set :show_banner, false
    set :root_class, "w-full"
    set :strategy_class, "w-full"
  end

  override AshAuthentication.Phoenix.Components.SignOut do
    set :root_class, "w-full"
    set :h2_class, @heading
    set :info_text_class, "mb-4 text-sm text-neutral-700"
    set :button_class, @button
  end

  override AshAuthentication.Phoenix.Components.Reset do
    set :root_class, "w-full"
    set :strategy_class, "w-full"
  end

  override AshAuthentication.Phoenix.Components.Confirm do
    set :root_class, "w-full"
    set :strategy_class, "w-full"
  end

  override AshAuthentication.Phoenix.Components.Confirm.Input do
    set :submit_class, @button
  end

  override AshAuthentication.Phoenix.Components.Password do
    set :register_extra_component, &OdinMarketWeb.AuthComponents.register_extra/1
    set :root_class, "w-full"
    set :toggler_class, "text-sm font-medium text-neutral-900 underline"
    set :interstitial_class, "mt-2 flex flex-wrap items-center justify-between gap-2"
  end

  override AshAuthentication.Phoenix.Components.Password.SignInForm do
    set :root_class, "w-full"
    set :label_class, @heading
  end

  override AshAuthentication.Phoenix.Components.Password.RegisterForm do
    set :root_class, "w-full"
    set :label_class, @heading
  end

  override AshAuthentication.Phoenix.Components.Password.ResetForm do
    set :root_class, "w-full"
    set :label_class, @heading
  end

  override AshAuthentication.Phoenix.Components.Password.Input do
    set :field_class, "mb-3 text-neutral-900"
    set :label_class, @label
    set :input_class, @input
    set :input_class_with_error, @input_error
    set :submit_class, @button
    set :error_ul, "my-2 text-sm text-red-700"
    set :remember_me_class, "mb-2 flex items-center gap-2 text-sm text-neutral-800"
    set :checkbox_label_class, "text-sm font-medium text-neutral-800"
  end
end
