defmodule Wayfinder.Turnstile do
  @moduledoc """
  Server-side check of a Cloudflare Turnstile token (the spam check on our
  public forms).

  The browser widget (see `assets/js/hooks/turnstile.js`) puts a token in the
  form; we send it to Cloudflare with our secret key to confirm it's real.

  Config (see config/*.exs):

      config :wayfinder, Wayfinder.Turnstile,
        site_key: "...",      # public, rendered in the page
        secret_key: "...",    # private, only used here
        req_options: []       # extra Req options (tests plug in a stub here)
  """

  @verify_url "https://challenges.cloudflare.com/turnstile/v0/siteverify"

  def site_key, do: config(:site_key)

  @doc """
  Returns `:ok` if Cloudflare accepts the token, otherwise `{:error, reason}`.
  """
  def verify(token, remote_ip \\ nil)

  def verify(token, remote_ip) when is_binary(token) and token != "" do
    form = %{secret: config(:secret_key), response: token, remoteip: remote_ip}

    options =
      [url: @verify_url, form: Map.reject(form, fn {_key, value} -> is_nil(value) end)]
      |> Keyword.merge(config(:req_options) || [])

    case Req.post(options) do
      {:ok, %Req.Response{status: 200, body: %{"success" => true}}} -> :ok
      {:ok, %Req.Response{body: body}} -> {:error, {:rejected, body}}
      {:error, exception} -> {:error, exception}
    end
  end

  def verify(_token, _remote_ip), do: {:error, :missing_token}

  defp config(key) do
    :wayfinder
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(key)
  end
end
