defmodule Wayfinder.Geocoding.Nominatim do
  @moduledoc """
  Geocoding with OpenStreetMap's free Nominatim service.

  Their usage policy asks for an identifying User-Agent and at most one
  request per second, and forbids search-as-you-type. We only search when
  someone presses "Find on map", which keeps us well within that.
  https://operations.osmfoundation.org/policies/nominatim/

      config :wayfinder, Wayfinder.Geocoding.Nominatim,
        user_agent: "Wayfinder (admin@yourdomain.org)",
        req_options: []
  """
  @behaviour Wayfinder.Geocoding

  @search_url "https://nominatim.openstreetmap.org/search"

  @impl true
  def search(query) do
    options =
      [
        url: @search_url,
        params: [q: query, format: "jsonv2", addressdetails: 1, limit: 5],
        headers: [user_agent: config(:user_agent) || "Wayfinder church directory"],
        receive_timeout: 10_000,
        # Fail fast: someone is waiting on the "Find on map" button.
        retry: false
      ]
      |> Keyword.merge(config(:req_options) || [])

    case Req.get(options) do
      {:ok, %Req.Response{status: 200, body: places}} when is_list(places) ->
        {:ok, Enum.map(places, &to_result/1)}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_status, status}}

      {:error, exception} ->
        {:error, exception}
    end
  end

  # Nominatim returns coordinates as strings and puts the city in one of
  # several keys depending on the size of the place.
  defp to_result(place) do
    address = place["address"] || %{}

    %{
      label: place["display_name"],
      latitude: String.to_float(place["lat"]),
      longitude: String.to_float(place["lon"]),
      city: address["city"] || address["town"] || address["village"] || address["suburb"],
      region: address["state"] || address["county"],
      postal_code: address["postcode"],
      country: address["country"]
    }
  end

  defp config(key) do
    :wayfinder
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(key)
  end
end
