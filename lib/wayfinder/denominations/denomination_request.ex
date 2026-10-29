defmodule Wayfinder.Denominations.DenominationRequest do
  @moduledoc """
  A request to add a denomination that isn't listed yet.

  Statuses:
    * `:pending`  - waiting for the super admin
    * `:approved` - a new denomination was created from it
    * `:merged`   - it was mapped onto an existing denomination
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "denomination_requests" do
    field :name, :string
    field :status, Ecto.Enum, values: [:pending, :approved, :merged], default: :pending
    field :resolved_at, :utc_datetime

    belongs_to :resolved_denomination, Wayfinder.Denominations.Denomination
    belongs_to :resolved_by, Wayfinder.Accounts.User
    has_many :churches, Wayfinder.Directory.Church

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(request, attrs) do
    request
    |> cast(attrs, [:name])
    |> update_change(:name, &String.trim/1)
    |> validate_required([:name])
    |> validate_length(:name, max: 120)
    |> unique_constraint(:name, name: :denomination_requests_pending_name_index)
  end

  @doc """
  Marks the request as resolved. `status` is `:approved` or `:merged`.
  """
  def resolve_changeset(request, status, denomination, user) do
    change(request,
      status: status,
      resolved_denomination_id: denomination.id,
      resolved_by_id: user.id,
      resolved_at: DateTime.utc_now(:second)
    )
  end
end
