defmodule Wayfinder.Directory.Policy do
  @moduledoc """
  The single place that decides who may edit a church.

  Today an editor is either:
    * the platform super admin (signed in), or
    * someone holding a valid "manage" link for that church.

  When church owners get accounts, they're already covered by the
  `owner_id` clause below: just set `church.owner_id` and let owners sign in.
  """
  alias Wayfinder.Accounts.Scope
  alias Wayfinder.Directory.Church

  @doc """
  `actor` is a `%Scope{}` for signed-in users, or `{:manage_link, church}`
  for the church a manage link resolved to.
  """
  def can_manage?(actor, church)

  def can_manage?(%Scope{} = scope, %Church{} = church) do
    Scope.super_admin?(scope) or church.owner_id == scope.user.id
  end

  def can_manage?({:manage_link, %Church{id: id}}, %Church{id: id}), do: true

  def can_manage?(_actor, _church), do: false
end
