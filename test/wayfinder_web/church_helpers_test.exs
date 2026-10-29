defmodule WayfinderWeb.ChurchHelpersTest do
  use ExUnit.Case, async: true

  doctest WayfinderWeb.ChurchHelpers

  alias Wayfinder.Directory.Activity
  alias WayfinderWeb.ChurchHelpers

  @service %Activity{name: "Service", days: [7], starts_at: ~T[09:00:00], ends_at: ~T[11:00:00]}
  @early %Activity{name: "Prayer", days: [3, 7], starts_at: ~T[06:00:00]}

  test "schedule_by_day/1 groups by weekday and sorts by time" do
    assert ChurchHelpers.schedule_by_day([@service, @early]) == [
             {"Wednesday", [@early]},
             {"Sunday", [@early, @service]}
           ]
  end

  test "format_time_range/1" do
    assert ChurchHelpers.format_time_range(@service) == "9:00 AM – 11:00 AM"
    assert ChurchHelpers.format_time_range(@early) == "6:00 AM"
  end

  test "schedule_summary/2" do
    assert ChurchHelpers.schedule_summary([@service, @early]) == [
             "Wed 6:00 AM · Prayer",
             "Sun 6:00 AM · Prayer"
           ]
  end
end
