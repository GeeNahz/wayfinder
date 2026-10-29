defmodule Wayfinder.Directory do
  @moduledoc """
  Churches and their weekly activities: public registration, email
  verification, the public directory, and admin moderation.
  """
  import Ecto.Query

  alias Ecto.Multi
  alias Wayfinder.Repo
  alias Wayfinder.Denominations
  alias Wayfinder.Directory.{Activity, Church, ChurchNotifier, ChurchToken, Geo}

  ## Registration (public)

  def change_registration(%Church{} = church \\ %Church{}, attrs \\ %{}) do
    Church.registration_changeset(church, attrs)
  end

  @doc """
  Saves a new church as `:unverified` and emails a verification link.

  `verify_url_fun` turns the secret token into a full URL, e.g.
  `&url(~p"/churches/verify/\#{&1}")`.
  """
  def register_church(attrs, verify_url_fun) when is_function(verify_url_fun, 1) do
    Multi.new()
    |> Multi.insert(:church, Church.registration_changeset(%Church{}, attrs))
    |> Multi.run(:token, fn repo, %{church: church} ->
      {encoded_token, token} = ChurchToken.build(church, "verify")

      with {:ok, _token} <- repo.insert(token) do
        {:ok, encoded_token}
      end
    end)
    |> Repo.transact()
    |> case do
      {:ok, %{church: church, token: encoded_token}} ->
        ChurchNotifier.deliver_verification(church, verify_url_fun.(encoded_token))
        {:ok, church}

      {:error, :church, changeset, _changes} ->
        {:error, changeset}
    end
  end

  @doc """
  Confirms the submitter's email using the token from the verification link.

  The church moves to `:pending` (waiting for admin review). If it asked for
  a new denomination, it's attached to a pending denomination request.
  Returns `{:ok, church}` or `:error` for bad/expired links.
  """
  def verify_church(encoded_token) do
    with {:ok, query} <- ChurchToken.church_query(encoded_token, "verify"),
         %Church{} = church <- Repo.one(query) do
      Multi.new()
      |> Multi.run(:denomination_request_id, fn _repo, _changes ->
        link_denomination_request(church)
      end)
      |> Multi.update(:church, fn %{denomination_request_id: request_id} ->
        Ecto.Changeset.change(church,
          status: :pending,
          email_verified_at: DateTime.utc_now(:second),
          denomination_request_id: request_id
        )
      end)
      |> Multi.delete_all(:tokens, tokens_query(church, "verify"))
      |> Repo.transact()
      |> case do
        {:ok, %{church: church}} -> {:ok, church}
        {:error, _step, _reason, _changes} -> :error
      end
    else
      _ -> :error
    end
  end

  defp link_denomination_request(%Church{requested_denomination: nil}), do: {:ok, nil}

  defp link_denomination_request(%Church{requested_denomination: name}) do
    with {:ok, request} <- Denominations.find_or_create_pending_request(name) do
      {:ok, request.id}
    end
  end

  ## Public directory

  @doc """
  Approved churches for the public map and list.

  Supported filters (all optional):
    * `"q"` - text matched against the name, city and region
    * `"denomination"` - a denomination slug
    * `"day"` - an ISO weekday (1 = Monday ... 7 = Sunday) with at least one activity
    * `"near"` - `{latitude, longitude}`; results are sorted by distance and
      each church gets its `distance_km` filled in
  """
  def list_public_churches(filters \\ %{}) do
    churches =
      from(c in Church, where: c.status == :approved, order_by: c.name)
      |> filter_by_text(filters["q"])
      |> filter_by_denomination(filters["denomination"])
      |> filter_by_day(filters["day"])
      |> preload([:denomination, :activities])
      |> Repo.all()

    case filters["near"] do
      {lat, lng} -> sort_by_distance(churches, {lat, lng})
      _ -> churches
    end
  end

  defp filter_by_text(query, text) when is_binary(text) and text != "" do
    pattern = "%#{escape_like(String.trim(text))}%"

    where(
      query,
      [c],
      ilike(c.name, ^pattern) or ilike(c.city, ^pattern) or ilike(c.region, ^pattern)
    )
  end

  defp filter_by_text(query, _text), do: query

  defp filter_by_denomination(query, slug) when is_binary(slug) and slug != "" do
    from c in query, join: d in assoc(c, :denomination), where: d.slug == ^slug
  end

  defp filter_by_denomination(query, _slug), do: query

  defp filter_by_day(query, day) when is_integer(day) and day in 1..7 do
    has_activity_that_day =
      from a in Activity, where: a.church_id == parent_as(:church).id and ^day in a.days

    from c in query, as: :church, where: exists(has_activity_that_day)
  end

  defp filter_by_day(query, _day), do: query

  # Distance is worked out in Elixir, which is simple and fast enough for
  # thousands of churches. Move it into SQL (or PostGIS) if the directory
  # grows much larger.
  defp sort_by_distance(churches, origin) do
    churches
    |> Enum.map(fn church ->
      %{church | distance_km: Geo.distance_km(origin, {church.latitude, church.longitude})}
    end)
    |> Enum.sort_by(& &1.distance_km)
  end

  # Stops "%" and "_" typed by visitors from acting as SQL wildcards.
  defp escape_like(text), do: String.replace(text, ~r/([\\%_])/, "\\\\\\1")

  @doc """
  An approved church by its slug, or `nil`.
  """
  def get_public_church_by_slug(slug) do
    Church
    |> where([c], c.slug == ^slug and c.status == :approved)
    |> preload([:denomination, :activities])
    |> Repo.one()
  end

  ## Editing (manage link and admin)

  @doc """
  The church a valid manage link points to, or `nil`.
  """
  def get_church_by_manage_token(encoded_token) do
    case ChurchToken.church_query(encoded_token, "manage") do
      {:ok, query} -> query |> Repo.one() |> preload_for_form()
      :error -> nil
    end
  end

  @doc """
  Creates a manage link token for the church. Returns the encoded token.
  """
  def create_manage_token(%Church{} = church) do
    {encoded_token, token} = ChurchToken.build(church, "manage")
    Repo.insert!(token)
    encoded_token
  end

  @doc "Invalidates every manage link sent for this church."
  def revoke_manage_links(%Church{} = church) do
    {count, _} = Repo.delete_all(tokens_query(church, "manage"))
    count
  end

  def change_church(%Church{} = church, attrs \\ %{}) do
    Church.form_changeset(church, attrs)
  end

  @doc """
  Saves edits to a church (from a manage link or the admin). Changes are
  live straight away.
  """
  def update_church(%Church{} = church, attrs) do
    church
    |> Church.form_changeset(attrs)
    |> Ecto.Changeset.put_change(:last_edited_at, DateTime.utc_now(:second))
    |> Repo.update()
  end

  defp preload_for_form(nil), do: nil
  defp preload_for_form(church), do: Repo.preload(church, [:denomination, :activities])

  ## Admin

  @doc """
  Churches for the admin list, newest first. Unverified submissions are
  hidden (they're not real until the email is confirmed).

  Filters: `"status"` (a status name) and `"q"` (name/city/email text).
  """
  def list_churches(filters \\ %{}) do
    query =
      from c in Church,
        where: c.status != :unverified,
        order_by: [desc: c.inserted_at],
        preload: [:denomination]

    query =
      case filters["status"] do
        status when status in ~w(pending approved rejected suspended) ->
          where(query, [c], c.status == ^String.to_existing_atom(status))

        _ ->
          query
      end

    query =
      case filters["q"] do
        text when is_binary(text) and text != "" ->
          pattern = "%#{escape_like(String.trim(text))}%"

          where(
            query,
            [c],
            ilike(c.name, ^pattern) or ilike(c.city, ^pattern) or
              ilike(c.contact_email, ^pattern)
          )

        _ ->
          query
      end

    Repo.all(query)
  end

  def get_church!(id) do
    Church
    |> Repo.get!(id)
    |> Repo.preload([:denomination, :denomination_request, :activities])
  end

  @doc """
  How many (verified) churches are in each status, e.g. `%{pending: 3, approved: 10}`.
  """
  def count_churches_by_status do
    from(c in Church,
      where: c.status != :unverified,
      group_by: c.status,
      select: {c.status, count(c.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  @doc "The most recently submitted (verified) churches."
  def list_recent_churches(limit \\ 5) do
    Repo.all(
      from c in Church,
        where: c.status != :unverified,
        order_by: [desc: c.inserted_at],
        limit: ^limit,
        preload: [:denomination]
    )
  end

  @doc """
  Approves a church so it appears publicly, and emails the submitter.

  A church that asked for a new denomination can't be approved until that
  request has been resolved: `{:error, :denomination_pending}`.
  """
  def approve_church(%Church{} = church, public_url_fun) when is_function(public_url_fun, 1) do
    if is_nil(church.denomination_id) do
      {:error, :denomination_pending}
    else
      result =
        church
        |> Ecto.Changeset.change(
          status: :approved,
          approved_at: DateTime.utc_now(:second),
          rejection_reason: nil
        )
        |> Repo.update()

      with {:ok, church} <- result do
        ChurchNotifier.deliver_approved(church, public_url_fun.(church))
        {:ok, church}
      end
    end
  end

  @doc "Rejects a church with a reason, and emails the submitter."
  def reject_church(%Church{} = church, reason) do
    result =
      church
      |> Ecto.Changeset.change(status: :rejected, rejection_reason: reason)
      |> Ecto.Changeset.validate_required(:rejection_reason, message: "please give a reason")
      |> Repo.update()

    with {:ok, church} <- result do
      ChurchNotifier.deliver_rejected(church)
      {:ok, church}
    end
  end

  @doc "Hides an approved church from the public without deleting it."
  def suspend_church(%Church{status: :approved} = church) do
    church |> Ecto.Changeset.change(status: :suspended) |> Repo.update()
  end

  def unsuspend_church(%Church{status: :suspended} = church) do
    church |> Ecto.Changeset.change(status: :approved) |> Repo.update()
  end

  def delete_church(%Church{} = church), do: Repo.delete(church)

  ## Housekeeping (run by Wayfinder.Directory.Janitor)

  @doc """
  Deletes churches whose email was never verified within 48 hours.
  """
  def delete_expired_unverified_churches do
    cutoff = DateTime.add(DateTime.utc_now(), -ChurchToken.validity_in_hours("verify"), :hour)

    {count, _} =
      Repo.delete_all(
        from c in Church, where: c.status == :unverified and c.inserted_at < ^cutoff
      )

    count
  end

  @doc "Deletes expired verify/manage tokens."
  def delete_expired_tokens do
    {count, _} =
      Repo.delete_all(from t in ChurchToken, where: t.expires_at < ^DateTime.utc_now())

    count
  end

  defp tokens_query(church, context) do
    from t in ChurchToken, where: t.church_id == ^church.id and t.context == ^context
  end
end
