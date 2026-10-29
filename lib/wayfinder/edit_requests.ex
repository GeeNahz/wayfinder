defmodule Wayfinder.EditRequests do
  @moduledoc """
  Requests from a church's submitter to edit the listing.

  Flow:
    1. On the public church page, someone enters their email (+ Turnstile).
    2. If it matches the church's verified contact email, a pending request
       is stored. Either way they see the same message, so nobody can use
       the form to find out which email belongs to a church.
    3. The super admin grants it: a 7-day manage link is emailed to the
       church's contact email (never to an address typed into the form).
  """
  import Ecto.Query

  alias Ecto.Multi
  alias Wayfinder.Repo
  alias Wayfinder.Accounts.Scope
  alias Wayfinder.Directory
  alias Wayfinder.Directory.{Church, ChurchNotifier}
  alias Wayfinder.EditRequests.EditRequest

  def change_edit_request(attrs \\ %{}) do
    EditRequest.changeset(%EditRequest{}, attrs)
  end

  @doc """
  Handles the public "request to edit" form.

  Returns `{:error, changeset}` if the form is invalid. Otherwise always
  returns `:ok`; a request is only stored when the email matches and the
  church has no other pending request.
  """
  def request_edit(%Church{} = church, attrs) do
    changeset = EditRequest.changeset(%EditRequest{church_id: church.id}, attrs)

    with {:ok, edit_request} <- Ecto.Changeset.apply_action(changeset, :insert) do
      if email_matches?(church, edit_request.email) and not pending_request?(church) do
        Repo.insert!(changeset)
      end

      :ok
    end
  end

  defp email_matches?(church, email) do
    church.email_verified_at != nil and
      String.downcase(church.contact_email) == String.downcase(email)
  end

  defp pending_request?(church) do
    Repo.exists?(from r in EditRequest, where: r.church_id == ^church.id and r.status == :pending)
  end

  @doc "Pending requests, oldest first, with their church."
  def list_pending_edit_requests do
    Repo.all(
      from r in EditRequest,
        where: r.status == :pending,
        order_by: r.inserted_at,
        preload: [:church]
    )
  end

  def count_pending_edit_requests do
    Repo.aggregate(from(r in EditRequest, where: r.status == :pending), :count)
  end

  def get_edit_request!(id), do: EditRequest |> Repo.get!(id) |> Repo.preload(:church)

  @doc """
  Grants a request and emails a manage link to the church's contact email.

  `manage_url_fun` receives the church and the secret token and returns the
  full URL, e.g. `&url(~p"/churches/\#{&1.slug}/manage/\#{&2}")`.
  """
  def grant_edit_request(
        %Scope{} = scope,
        %EditRequest{status: :pending} = edit_request,
        manage_url_fun
      )
      when is_function(manage_url_fun, 2) do
    church = Repo.preload(edit_request, :church).church

    Multi.new()
    |> Multi.update(
      :edit_request,
      EditRequest.resolve_changeset(edit_request, :granted, scope.user)
    )
    |> Multi.run(:token, fn _repo, _changes -> {:ok, Directory.create_manage_token(church)} end)
    |> Repo.transact()
    |> case do
      {:ok, %{edit_request: edit_request, token: token}} ->
        ChurchNotifier.deliver_manage_link(church, manage_url_fun.(church, token))
        {:ok, edit_request}

      {:error, _step, reason, _changes} ->
        {:error, reason}
    end
  end

  def reject_edit_request(%Scope{} = scope, %EditRequest{status: :pending} = edit_request) do
    edit_request
    |> EditRequest.resolve_changeset(:rejected, scope.user)
    |> Repo.update()
  end
end
