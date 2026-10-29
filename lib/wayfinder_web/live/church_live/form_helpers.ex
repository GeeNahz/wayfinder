defmodule WayfinderWeb.ChurchLive.FormHelpers do
  @moduledoc """
  Small helpers shared by every LiveView that shows the church form
  (`WayfinderWeb.ChurchFormComponents`). They work on the raw form params
  (a map with string keys) and return new params.
  """
  alias Wayfinder.Denominations
  alias Wayfinder.Geocoding

  @doc "`[{name, id}]` options for the denomination select."
  def denomination_options do
    Enum.map(Denominations.list_active_denominations(), &{&1.name, &1.id})
  end

  @doc """
  Searches for the address typed into the form.

  Returns `{:ok, places}` or `{:error, message}` with a message to show.
  """
  def geocode(params) do
    query =
      ~w(address_line1 city region postal_code country)
      |> Enum.map(&params[&1])
      |> Enum.reject(&(&1 in [nil, ""]))
      |> Enum.join(", ")

    case Geocoding.search(query) do
      {:ok, []} when query == "" ->
        {:error, "Type the address first, then press \"Find on map\"."}

      {:ok, []} ->
        {:error, "We couldn't find that address. Try fewer details, or click the map instead."}

      {:ok, places} ->
        {:ok, places}

      {:error, _reason} ->
        {:error, "Address search is unavailable right now. Please click the map instead."}
    end
  end

  @doc """
  Copies a picked search result into the params: the coordinates always,
  and the city/region/postal code/country only where they're still blank.
  """
  def apply_place(params, place) do
    blanks_filled =
      for field <- [:city, :region, :postal_code, :country],
          params[to_string(field)] in [nil, ""],
          place[field],
          into: %{},
          do: {to_string(field), place[field]}

    params
    |> Map.merge(blanks_filled)
    |> apply_pin(place.latitude, place.longitude)
  end

  @doc "Stores the map pin position in the params."
  def apply_pin(params, lat, lng) do
    Map.merge(params, %{"latitude" => to_string(lat), "longitude" => to_string(lng)})
  end
end
