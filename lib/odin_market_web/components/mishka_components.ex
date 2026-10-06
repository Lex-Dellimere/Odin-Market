defmodule OdinMarketWeb.Components.MishkaComponents do
  defmacro __using__(_) do
    quote do
      import OdinMarketWeb.Components.Alert,
        only: [
          flash: 1,
          flash_group: 1,
          alert: 1,
          show_alert: 1,
          show_alert: 2,
          hide_alert: 1,
          hide_alert: 2
        ]

      import OdinMarketWeb.Components.Avatar, only: [avatar: 1, avatar_group: 1]

      import OdinMarketWeb.Components.Badge,
        only: [badge: 1, hide_badge: 1, hide_badge: 2, show_badge: 1, show_badge: 2]

      import OdinMarketWeb.Components.Button,
        only: [button_group: 1, button: 1, input_button: 1, button_link: 1, back: 1]

      import OdinMarketWeb.Components.Card,
        only: [card: 1, card_title: 1, card_media: 1, card_content: 1, card_footer: 1]

      import OdinMarketWeb.Components.Carousel, only: [carousel: 1]
      import OdinMarketWeb.Components.Chat, only: [chat: 1, chat_section: 1]

      import OdinMarketWeb.Components.CheckboxField,
        only: [checkbox_field: 1, group_checkbox: 1, checkbox_check: 3]

      import OdinMarketWeb.Components.Divider, only: [divider: 1, hr: 1]

      import OdinMarketWeb.Components.Drawer,
        only: [drawer: 1, hide_drawer: 2, hide_drawer: 3, show_drawer: 2, show_drawer: 3]

      import OdinMarketWeb.Components.FileField, only: [file_field: 1]
      import OdinMarketWeb.Components.Footer, only: [footer: 1, footer_section: 1]
      import OdinMarketWeb.Components.FormWrapper, only: [form_wrapper: 1, simple_form: 1]

      import OdinMarketWeb.Components.Icon, only: [icon: 1]
      import OdinMarketWeb.Components.Image, only: [image: 1]
      import OdinMarketWeb.Components.InputField, only: [input: 1, error: 1]
      import OdinMarketWeb.Components.Jumbotron, only: [jumbotron: 1]
      import OdinMarketWeb.Components.Layout, only: [flex: 1, grid: 1]

      import OdinMarketWeb.Components.Modal,
        only: [
          modal: 1,
          show_modal: 1,
          show_modal: 2,
          hide_modal: 1,
          hide_modal: 2,
          show: 1,
          show: 2,
          hide: 1,
          hide: 2
        ]

      import OdinMarketWeb.Components.NativeSelect,
        only: [native_select: 1, select_option_group: 1]

      import OdinMarketWeb.Components.Navbar, only: [navbar: 1, header: 1]
      import OdinMarketWeb.Components.NumberField, only: [number_field: 1]
      import OdinMarketWeb.Components.Pagination, only: [pagination: 1]
      import OdinMarketWeb.Components.PasswordField, only: [password_field: 1]

      import OdinMarketWeb.Components.Progress,
        only: [progress: 1, progress_section: 1, semi_circle_progress: 1, ring_progress: 1]

      import OdinMarketWeb.Components.ScrollArea, only: [scroll_area: 1]
      import OdinMarketWeb.Components.Skeleton, only: [skeleton: 1]
      import OdinMarketWeb.Components.Spinner, only: [spinner: 1]
      import OdinMarketWeb.Components.Table, only: [table: 1, th: 1, tr: 1, td: 1]
      import OdinMarketWeb.Components.TextField, only: [text_field: 1]
      import OdinMarketWeb.Components.TextareaField, only: [textarea_field: 1]
    end
  end
end
