defmodule Wayfinder.Directory.Geo do
  @moduledoc """
  Distance maths for "near me" searches.
  """

  @earth_radius_km 6371.0

  @doc """
  Straight-line distance in km between two `{latitude, longitude}` points
  (the haversine formula).

      iex> Wayfinder.Directory.Geo.distance_km({6.5244, 3.3792}, {6.5244, 3.3792})
      0.0
  """
  def distance_km({lat1, lng1}, {lat2, lng2}) do
    d_lat = degrees_to_radians(lat2 - lat1)
    d_lng = degrees_to_radians(lng2 - lng1)

    a =
      :math.sin(d_lat / 2) ** 2 +
        :math.cos(degrees_to_radians(lat1)) * :math.cos(degrees_to_radians(lat2)) *
          :math.sin(d_lng / 2) ** 2

    2 * @earth_radius_km * :math.asin(:math.sqrt(a))
  end

  defp degrees_to_radians(degrees), do: degrees * :math.pi() / 180
end
