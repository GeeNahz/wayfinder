defmodule Wayfinder.Denominations do
  @moduledoc """
  Denominations onboarded by the super admin, and requests from the public
  to add ones that aren't listed yet.
  """
  import Ecto.Query

  alias Ecto.Multi
  alias Wayfinder.Repo
  alias Wayfinder.Accounts.Scope
  alias Wayfinder.Denominations.{Denomination, DenominationRequest}
  alias Wayfinder.Directory.Church

  ## Denominations

  @doc """
  Denominations shown on the public registration form (not archived), A–Z.
  """
  def list_active_denominations do
    Repo.all(from d in Denomination, where: is_nil(d.archived_at), order_by: d.name)
  end

  @doc """
  All denominations for the admin, each with its number of churches.

  Returns a list of `{denomination, church_count}` tuples.
  """
  def list_denominations_with_church_counts do
    query =
      from d in Denomination,
        left_join: c in assoc(d, :churches),
        group_by: d.id,
        order_by: d.name,
        select: {d, count(c.id)}

    Repo.all(query)
  end

  def get_denomination!(id), do: Repo.get!(Denomination, id)

  def get_denomination_by_slug(slug), do: Repo.get_by(Denomination, slug: slug)

  def change_denomination(%Denomination{} = denomination, attrs \\ %{}) do
    Denomination.changeset(denomination, attrs)
  end

  def create_denomination(attrs) do
    %Denomination{}
    |> Denomination.changeset(attrs)
    |> Repo.insert()
  end

  def update_denomination(%Denomination{} = denomination, attrs) do
    denomination
    |> Denomination.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Hides a denomination from the public form. Existing churches keep it.
  """
  def archive_denomination(%Denomination{} = denomination) do
    denomination
    |> Ecto.Changeset.change(archived_at: DateTime.utc_now(:second))
    |> Repo.update()
  end

  def unarchive_denomination(%Denomination{} = denomination) do
    denomination
    |> Ecto.Changeset.change(archived_at: nil)
    |> Repo.update()
  end

  ## Denomination requests

  @doc """
  Pending requests, oldest first, with the churches waiting on each one.
  """
  def list_pending_requests do
    Repo.all(
      from r in DenominationRequest,
        where: r.status == :pending,
        order_by: r.inserted_at,
        preload: [:churches]
    )
  end

  def count_pending_requests do
    Repo.aggregate(from(r in DenominationRequest, where: r.status == :pending), :count)
  end

  def get_request!(id), do: Repo.get!(DenominationRequest, id)

  @doc """
  Returns the pending request with this name, creating it if needed.

  Several churches asking for the same denomination share one request.
  """
  def find_or_create_pending_request(name) do
    name = String.trim(name)

    case Repo.get_by(DenominationRequest, name: name, status: :pending) do
      nil -> Repo.insert(DenominationRequest.changeset(%DenominationRequest{}, %{name: name}))
      request -> {:ok, request}
    end
  end

  @doc """
  Approves a request by creating a new denomination from it.

  `attrs` holds the denomination's final `name`/`description`, so the admin
  can tidy up the spelling. Every church waiting on the request is moved
  onto the new denomination.
  """
  def approve_request(%Scope{} = scope, %DenominationRequest{status: :pending} = request, attrs) do
    Multi.new()
    |> Multi.insert(:denomination, Denomination.changeset(%Denomination{}, attrs))
    |> Multi.run(:request, fn repo, %{denomination: denomination} ->
      resolve_request(repo, scope, request, :approved, denomination)
    end)
    |> Repo.transact()
    |> case do
      {:ok, %{denomination: denomination}} -> {:ok, denomination}
      {:error, :denomination, changeset, _changes} -> {:error, changeset}
    end
  end

  @doc """
  Resolves a request by pointing it at an existing denomination
  (e.g. someone asked for "Baptist Church" when "Baptist" exists).
  """
  def merge_request(
        %Scope{} = scope,
        %DenominationRequest{status: :pending} = request,
        %Denomination{} = denomination
      ) do
    Multi.new()
    |> Multi.run(:request, fn repo, _changes ->
      resolve_request(repo, scope, request, :merged, denomination)
    end)
    |> Repo.transact()
    |> case do
      {:ok, _changes} -> {:ok, denomination}
      {:error, _step, reason, _changes} -> {:error, reason}
    end
  end

  # Marks the request resolved and moves its churches onto `denomination`.
  defp resolve_request(repo, scope, request, status, denomination) do
    {_count, _} =
      repo.update_all(
        from(c in Church, where: c.denomination_request_id == ^request.id),
        set: [
          denomination_id: denomination.id,
          requested_denomination: nil,
          updated_at: DateTime.utc_now(:second)
        ]
      )

    request
    |> DenominationRequest.resolve_changeset(status, denomination, scope.user)
    |> repo.update()
  end
end
