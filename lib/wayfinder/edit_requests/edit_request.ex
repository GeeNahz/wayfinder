defmodule Wayfinder.EditRequests.EditRequest do
  @moduledoc """
  A request from a church's submitter to edit the listing.

  The super admin grants it (which emails a manage link to the church's
  verified contact email) or rejects it.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "edit_requests" do
    field :email, :string
    field :message, :string
    field :status, Ecto.Enum, values: [:pending, :granted, :rejected], default: :pending
    field :resolved_at, :utc_datetime

    belongs_to :church, Wayfinder.Directory.Church
    belongs_to :resolved_by, Wayfinder.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for the public "request to edit" form.
  """
  def changeset(edit_request, attrs) do
    edit_request
    |> cast(attrs, [:email, :message])
    |> update_change(:email, &String.trim/1)
    |> validate_required([:email], message: "can't be blank")
    |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+\.[^@,;\s]+$/,
      message: "must be a valid email address"
    )
    |> validate_length(:message, max: 1000)
  end

  def resolve_changeset(edit_request, status, user) when status in [:granted, :rejected] do
    change(edit_request,
      status: status,
      resolved_by_id: user.id,
      resolved_at: DateTime.utc_now(:second)
    )
  end
end
