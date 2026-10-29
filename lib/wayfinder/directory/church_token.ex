defmodule Wayfinder.Directory.ChurchToken do
  @moduledoc """
  Secret links we email to a church's contact address.

  Two kinds (`context`):
    * `"verify"` - confirms the submitter owns the email (valid 48 hours)
    * `"manage"` - lets them edit the church after the admin grants it (valid 7 days)

  We only store a SHA-256 hash of the token. The raw token is only ever in
  the email, so a database leak doesn't leak working links. This is the same
  approach `phx.gen.auth` uses for `UserToken`.
  """
  use Ecto.Schema
  import Ecto.Query

  alias Wayfinder.Directory.Church

  @rand_size 32
  @validity_in_hours %{"verify" => 48, "manage" => 7 * 24}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "church_tokens" do
    field :hashed_token, :binary
    field :context, :string
    field :sent_to, :string
    field :expires_at, :utc_datetime

    belongs_to :church, Church

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def validity_in_hours(context), do: Map.fetch!(@validity_in_hours, context)

  @doc """
  Builds a token for the church's contact email.

  Returns `{encoded_token, %ChurchToken{}}`: put the encoded token in the
  email link and insert the struct into the database.
  """
  def build(%Church{} = church, context) when context in ["verify", "manage"] do
    token = :crypto.strong_rand_bytes(@rand_size)

    expires_at =
      DateTime.utc_now(:second)
      |> DateTime.add(validity_in_hours(context), :hour)

    {Base.url_encode64(token, padding: false),
     %__MODULE__{
       hashed_token: :crypto.hash(:sha256, token),
       context: context,
       sent_to: church.contact_email,
       expires_at: expires_at,
       church_id: church.id
     }}
  end

  @doc """
  Query returning the church for a valid, unexpired token.

  The token must also have been sent to the church's *current* contact
  email. Returns `:error` if the token can't be decoded.
  """
  def church_query(encoded_token, context) do
    case Base.url_decode64(encoded_token, padding: false) do
      {:ok, token} ->
        hashed_token = :crypto.hash(:sha256, token)

        query =
          from t in __MODULE__,
            join: c in assoc(t, :church),
            where:
              t.hashed_token == ^hashed_token and t.context == ^context and
                t.expires_at > ^DateTime.utc_now() and t.sent_to == c.contact_email,
            select: c

        {:ok, query}

      :error ->
        :error
    end
  end
end
