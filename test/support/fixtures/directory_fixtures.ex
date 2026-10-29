defmodule Wayfinder.DirectoryFixtures do
  @moduledoc """
  Test helpers for creating denominations, churches and edit requests.
  """
  alias Wayfinder.Repo
  alias Wayfinder.Denominations
  alias Wayfinder.Directory
  alias Wayfinder.Directory.Church

  def unique_denomination_name, do: "Denomination #{System.unique_integer([:positive])}"

  def denomination_fixture(attrs \\ %{}) do
    {:ok, denomination} =
      attrs
      |> Enum.into(%{name: unique_denomination_name()})
      |> Denominations.create_denomination()

    denomination
  end

  @doc "Form params (string keys, like a browser sends) for a valid church."
  def valid_church_params(overrides \\ %{}) do
    Map.merge(
      %{
        "name" => "Grace Chapel #{System.unique_integer([:positive])}",
        "address_line1" => "1 Hope Street",
        "city" => "Lagos",
        "country" => "Nigeria",
        "latitude" => "6.5244",
        "longitude" => "3.3792",
        "contact_email" => "pastor#{System.unique_integer([:positive])}@example.com",
        "activities" => %{
          "0" => %{"name" => "Sunday Service", "days" => ["7"], "starts_at" => "09:00"}
        }
      },
      overrides
    )
  end

  @doc """
  Inserts a church directly in the given status (default `:approved`).

  Pass `"denomination_id"` or `"requested_denomination"` in `params`;
  a new denomination is created if neither is given.
  """
  def church_fixture(params \\ %{}, status \\ :approved) do
    params =
      if Map.has_key?(params, "denomination_id") or Map.has_key?(params, "requested_denomination") do
        params
      else
        Map.put(params, "denomination_id", denomination_fixture().id)
      end

    %Church{}
    |> Church.registration_changeset(valid_church_params(params))
    |> Ecto.Changeset.change(
      status: status,
      email_verified_at: if(status != :unverified, do: DateTime.utc_now(:second)),
      approved_at: if(status == :approved, do: DateTime.utc_now(:second))
    )
    |> Repo.insert!()
    |> Repo.preload([:denomination, :activities])
  end

  @doc """
  Registers a church through the public flow. Returns `{church, verify_token}`.
  """
  def registered_church_fixture(params \\ %{}) do
    {:ok, church} =
      Directory.register_church(valid_church_params(params), fn token ->
        send(self(), {:verify_token, token})
        "http://example.com/verify/#{token}"
      end)

    receive do
      {:verify_token, token} -> {church, token}
    end
  end
end
