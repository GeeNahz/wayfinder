defmodule Wayfinder.Geocoding.NominatimTest do
  use ExUnit.Case, async: true

  alias Wayfinder.Geocoding.Nominatim

  test "maps Nominatim places to results" do
    Req.Test.stub(Nominatim, fn conn ->
      assert conn.query_params["q"] == "1 Hope Street, Lagos"
      assert [_user_agent] = Plug.Conn.get_req_header(conn, "user-agent")

      Req.Test.json(conn, [
        %{
          "display_name" => "1 Hope Street, Lagos, Nigeria",
          "lat" => "6.5244",
          "lon" => "3.3792",
          "address" => %{"town" => "Lagos", "state" => "Lagos", "country" => "Nigeria"}
        }
      ])
    end)

    assert {:ok, [result]} = Nominatim.search("1 Hope Street, Lagos")
    assert result.latitude == 6.5244
    assert result.longitude == 3.3792
    assert result.city == "Lagos"
    assert result.country == "Nigeria"
  end

  test "returns an error for a failed request" do
    Req.Test.stub(Nominatim, &Plug.Conn.send_resp(&1, 503, "busy"))
    assert {:error, {:http_status, 503}} = Nominatim.search("anything")
  end
end
