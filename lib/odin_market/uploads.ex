defmodule OdinMarket.Uploads do
  @placeholder "/images/placeholder.svg"
  @allowed ~w(.jpg .jpeg .png .webp)

  def placeholder, do: @placeholder

  def persist(socket, listing_id) do
    if upload?(socket) do
      Phoenix.LiveView.consume_uploaded_entries(socket, :images, fn %{path: path}, entry ->
        ext = entry.client_name |> Path.extname() |> String.downcase()
        ext = if ext in @allowed, do: ext, else: ".jpg"
        name = Ecto.UUID.generate() <> ext
        relative = Path.join(["uploads", "listings", listing_id, name])
        dest = Path.join([:code.priv_dir(:odin_market), "static", relative])
        File.mkdir_p!(Path.dirname(dest))
        File.cp!(path, dest)
        {:ok, "/#{relative}"}
      end)
    else
      []
    end
  end

  def delete_file(url) when is_binary(url) do
    relative = String.trim_leading(url, "/")
    root = Path.expand(Path.join([:code.priv_dir(:odin_market), "static", "uploads"]))
    dest = Path.expand(Path.join([:code.priv_dir(:odin_market), "static", relative]))

    if String.starts_with?(url, "/uploads/") and String.starts_with?(dest, root) do
      File.rm(dest)
    else
      :ok
    end
  end

  def delete_file(_), do: :ok

  defp upload?(socket) do
    match?(%{images: _}, socket.assigns[:uploads])
  end
end
