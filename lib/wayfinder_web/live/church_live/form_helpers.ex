defmodule WayfinderWeb.ChurchLive.FormHelpers do
  @moduledoc """
  Small helpers shared by every LiveView that shows the church form
  (`WayfinderWeb.ChurchFormComponents`).

  Those LiveViews keep two assigns: `:params` (the raw form params, a map
  with string keys) and `:form` (built from a changeset). The helpers read
  the current values from the form and return new params.
  """
  alias Wayfinder.Denominations
  alias Wayfinder.Directory.Church
  alias Wayfinder.Geocoding

  @address_fields [:address_line1, :city, :region, :postal_code, :country]

  @doc """
  `[{name, id}]` options for the denomination select.

  Pass the church being edited so its denomination stays selectable even
  if it has since been archived.
  """
  def denomination_options(church \\ nil) do
    active = Denominations.list_active_denominations()

    denominations =
      case church do
        %Church{denomination: %{} = current} ->
          if Enum.any?(active, &(&1.id == current.id)), do: active, else: active ++ [current]

        _ ->
          active
      end

    Enum.map(denominations, &{&1.name, &1.id})
  end

  @doc """
  Searches for the address currently in the form.

  Returns `{:ok, places}` or `{:error, message}` with a message to show.
  """
  def geocode(%Phoenix.HTML.Form{} = form) do
    query =
      @address_fields
      |> Enum.map(&form[&1].value)
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
  def apply_place(params, %Phoenix.HTML.Form{} = form, place) do
    blanks_filled =
      for field <- [:city, :region, :postal_code, :country],
          form[field].value in [nil, ""],
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
