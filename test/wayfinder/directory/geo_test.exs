defmodule Wayfinder.Directory.GeoTest do
  use ExUnit.Case, async: true

  doctest Wayfinder.Directory.Geo

  alias Wayfinder.Directory.Geo

  test "distance between Lagos and Abuja is about 525 km" do
    distance = Geo.distance_km({6.5244, 3.3792}, {9.0765, 7.3986})
    assert_in_delta distance, 525, 10
  end
end
