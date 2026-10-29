defmodule Wayfinder.TurnstileTest do
  use ExUnit.Case, async: true

  alias Wayfinder.Turnstile

  test "accepts a token Cloudflare confirms" do
    Req.Test.stub(Turnstile, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert URI.decode_query(body)["response"] == "good-token"
      assert URI.decode_query(body)["remoteip"] == "1.2.3.4"

      Req.Test.json(conn, %{"success" => true})
    end)

    assert :ok = Turnstile.verify("good-token", "1.2.3.4")
  end

  test "rejects a token Cloudflare refuses" do
    Req.Test.stub(Turnstile, fn conn ->
      Req.Test.json(conn, %{"success" => false, "error-codes" => ["invalid-input-response"]})
    end)

    assert {:error, {:rejected, _body}} = Turnstile.verify("bad-token")
  end

  test "rejects a missing token without calling Cloudflare" do
    assert {:error, :missing_token} = Turnstile.verify("")
    assert {:error, :missing_token} = Turnstile.verify(nil)
  end
end
