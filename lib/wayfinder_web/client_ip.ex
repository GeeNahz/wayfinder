defmodule WayfinderWeb.ClientIp do
  @moduledoc """
  Works out the visitor's IP address inside a LiveView (sent to Turnstile,
  which uses it as an extra, optional signal).

  Behind Cloudflare, the visitor's IP is the *last* entry of the
  `x-forwarded-for` header (Cloudflare appends it). Otherwise we fall back to
  the address of the connection itself. Only call this from `mount/3`,
  where connect info is available.
  """
  import Phoenix.LiveView, only: [connected?: 1, get_connect_info: 2]

  def from_socket(socket) do
    if connected?(socket) do
      forwarded_ip(get_connect_info(socket, :x_headers)) ||
        peer_ip(get_connect_info(socket, :peer_data))
    end
  end

  defp forwarded_ip(headers) when is_list(headers) do
    case List.keyfind(headers, "x-forwarded-for", 0) do
      {_name, value} -> value |> String.split(",") |> List.last() |> String.trim()
      nil -> nil
    end
  end

  defp forwarded_ip(_headers), do: nil

  defp peer_ip(%{address: address}), do: address |> :inet.ntoa() |> to_string()
  defp peer_ip(_peer_data), do: nil
end
