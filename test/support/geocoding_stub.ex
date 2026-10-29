defmodule Wayfinder.Geocoding.Stub do
  @moduledoc """
  Fake geocoder used in tests (configured in config/test.exs).

  Any query returns one match in Lagos, except "nowhere" which returns none.
  """
  @behaviour Wayfinder.Geocoding

  @impl true
  def search("nowhere"), do: {:ok, []}

  def search(query) do
    {:ok,
     [
       %{
         label: "#{query}, Lagos, Nigeria",
         latitude: 6.5244,
         longitude: 3.3792,
         city: "Lagos",
         region: "Lagos State",
         postal_code: "100001",
         country: "Nigeria"
       }
     ]}
  end
end
