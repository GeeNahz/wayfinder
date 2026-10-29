defmodule WayfinderWeb.ChurchHelpers do
  @moduledoc """
  Formatting helpers for showing churches and their schedules.
  """
  alias Wayfinder.Directory.{Activity, Church}

  @doc ~S"""
  "9:00 AM" style times.

      iex> WayfinderWeb.ChurchHelpers.format_time(~T[18:30:00])
      "6:30 PM"
  """
  def format_time(nil), do: nil
  def format_time(%Time{} = time), do: Calendar.strftime(time, "%-I:%M %p")

  @doc ~S"""
  "9:00 AM – 11:00 AM", or just the start time when there's no end.
  """
  def format_time_range(%Activity{starts_at: starts_at, ends_at: nil}), do: format_time(starts_at)

  def format_time_range(%Activity{starts_at: starts_at, ends_at: ends_at}) do
    "#{format_time(starts_at)} – #{format_time(ends_at)}"
  end

  @doc ~S"""
  Distances for "near me" results.

      iex> WayfinderWeb.ChurchHelpers.format_distance(0.45)
      "450 m"
      iex> WayfinderWeb.ChurchHelpers.format_distance(12.34)
      "12.3 km"
  """
  def format_distance(nil), do: nil
  def format_distance(km) when km < 1, do: "#{round(km * 1000)} m"
  def format_distance(km), do: "#{Float.round(km, 1)} km"

  @doc """
  Groups activities by weekday (Monday first), each day sorted by start time.
  Days with no activities are left out.

  Returns `[{"Sunday", [%Activity{}, ...]}, ...]`.
  """
  def schedule_by_day(activities) do
    for {day, name} <- Activity.weekdays(),
        day_activities = Enum.filter(activities, &(day in &1.days)),
        day_activities != [] do
      {name, Enum.sort_by(day_activities, & &1.starts_at, Time)}
    end
  end

  @doc """
  A short "Sun 9:00 AM · Sunday Service" summary of the first few activities.
  """
  def schedule_summary(activities, limit \\ 2) do
    activities
    |> schedule_by_day()
    |> Enum.flat_map(fn {day, day_activities} ->
      Enum.map(
        day_activities,
        &"#{String.slice(day, 0, 3)} #{format_time(&1.starts_at)} · #{&1.name}"
      )
    end)
    |> Enum.take(limit)
  end

  @doc "Link that opens the church in Google Maps."
  def google_maps_url(%Church{latitude: lat, longitude: lng}) do
    "https://www.google.com/maps/search/?api=1&query=#{lat},#{lng}"
  end

  @doc "Link to Google Maps directions to the church."
  def directions_url(%Church{latitude: lat, longitude: lng}) do
    "https://www.google.com/maps/dir/?api=1&destination=#{lat},#{lng}"
  end

  @doc """
  The data a map pin needs (see assets/js/hooks/church_map.js).
  """
  def map_marker(%Church{} = church, url) do
    %{
      id: church.id,
      name: church.name,
      lat: church.latitude,
      lng: church.longitude,
      address: Church.full_address(church),
      denomination: Church.denomination_name(church),
      url: url
    }
  end
end
