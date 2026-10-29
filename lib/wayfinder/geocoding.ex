defmodule Wayfinder.Geocoding do
  @moduledoc """
  Turns an address into map coordinates ("Find on map" on the church form).

  This module defines the behaviour every geocoding provider implements and
  forwards calls to the configured one:

      config :wayfinder, :geocoder, Wayfinder.Geocoding.Nominatim

  To switch providers later (e.g. Google or Mapbox), write a new module with
  `@behaviour Wayfinder.Geocoding` and change that config line.
  """

  @typedoc "One search match, with address parts we can copy into the form."
  @type result :: %{
          label: String.t(),
          latitude: float(),
          longitude: float(),
          city: String.t() | nil,
          region: String.t() | nil,
          postal_code: String.t() | nil,
          country: String.t() | nil
        }

  @callback search(query :: String.t()) :: {:ok, [result()]} | {:error, term()}

  @doc """
  Searches for an address. Returns at most 5 matches.
  """
  def search(query) when is_binary(query) do
    case String.trim(query) do
      "" -> {:ok, []}
      query -> impl().search(query)
    end
  end

  defp impl, do: Application.get_env(:wayfinder, :geocoder, Wayfinder.Geocoding.Nominatim)
end
