defmodule Wayfinder.Directory.PolicyTest do
  use ExUnit.Case, async: true

  alias Wayfinder.Accounts.{Scope, User}
  alias Wayfinder.Directory.{Church, Policy}

  @church %Church{id: "church-1", owner_id: "owner-1"}

  test "super admins can manage any church" do
    assert Policy.can_manage?(Scope.for_user(%User{id: "admin", role: :super_admin}), @church)
  end

  test "an owner can manage their own church only" do
    assert Policy.can_manage?(Scope.for_user(%User{id: "owner-1", role: :owner}), @church)
    refute Policy.can_manage?(Scope.for_user(%User{id: "owner-2", role: :owner}), @church)
  end

  test "a manage link only works for its own church" do
    assert Policy.can_manage?({:manage_link, %Church{id: "church-1"}}, @church)
    refute Policy.can_manage?({:manage_link, %Church{id: "church-2"}}, @church)
    refute Policy.can_manage?(nil, @church)
  end
end
