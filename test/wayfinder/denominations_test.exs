defmodule Wayfinder.DenominationsTest do
  use Wayfinder.DataCase, async: true

  import Wayfinder.AccountsFixtures
  import Wayfinder.DirectoryFixtures

  alias Wayfinder.Accounts.Scope
  alias Wayfinder.Denominations
  alias Wayfinder.Repo

  describe "denominations" do
    test "create_denomination/1 sets a slug and rejects duplicates (any case)" do
      assert {:ok, denomination} = Denominations.create_denomination(%{name: " Baptist "})
      assert denomination.name == "Baptist"
      assert denomination.slug == "baptist"

      assert {:error, changeset} = Denominations.create_denomination(%{name: "BAPTIST"})
      assert "has already been taken" in errors_on(changeset).name
    end

    test "archived denominations are hidden from the public list" do
      kept = denomination_fixture(%{name: "Anglican"})
      {:ok, _archived} = Denominations.archive_denomination(denomination_fixture())

      assert Denominations.list_active_denominations() == [kept]
    end

    test "list_denominations_with_church_counts/0 counts churches" do
      denomination = denomination_fixture()
      church_fixture(%{"denomination_id" => denomination.id})
      church_fixture(%{"denomination_id" => denomination.id})

      assert {_denomination, 2} =
               Enum.find(
                 Denominations.list_denominations_with_church_counts(),
                 fn {d, _count} -> d.id == denomination.id end
               )
    end
  end

  describe "denomination requests" do
    setup do
      %{scope: Scope.for_user(super_admin_fixture())}
    end

    test "find_or_create_pending_request/1 reuses a pending request with the same name" do
      {:ok, first} = Denominations.find_or_create_pending_request("Grace Fellowship")
      {:ok, second} = Denominations.find_or_create_pending_request("grace fellowship ")

      assert first.id == second.id
      assert Denominations.count_pending_requests() == 1
    end

    test "approve_request/3 creates the denomination and moves churches onto it", %{scope: scope} do
      {:ok, request} = Denominations.find_or_create_pending_request("Grace Fellowship")

      church =
        church_fixture(%{"requested_denomination" => "Grace Fellowship"}, :pending)
        |> Ecto.Changeset.change(denomination_request_id: request.id)
        |> Repo.update!()

      assert {:ok, denomination} =
               Denominations.approve_request(scope, request, %{name: "Grace Fellowship Church"})

      church = Repo.reload!(church)
      assert church.denomination_id == denomination.id
      assert church.requested_denomination == nil

      request = Denominations.get_request!(request.id)
      assert request.status == :approved
      assert request.resolved_by_id == scope.user.id
      assert Denominations.list_pending_requests() == []
    end

    test "approve_request/3 returns the changeset if the name is taken", %{scope: scope} do
      denomination_fixture(%{name: "Baptist"})
      {:ok, request} = Denominations.find_or_create_pending_request("Baptist")

      assert {:error, %Ecto.Changeset{}} =
               Denominations.approve_request(scope, request, %{name: "Baptist"})

      assert Denominations.get_request!(request.id).status == :pending
    end

    test "merge_request/3 maps the request onto an existing denomination", %{scope: scope} do
      existing = denomination_fixture(%{name: "Baptist"})
      {:ok, request} = Denominations.find_or_create_pending_request("Baptist Church")

      church =
        church_fixture(%{"requested_denomination" => "Baptist Church"}, :pending)
        |> Ecto.Changeset.change(denomination_request_id: request.id)
        |> Repo.update!()

      assert {:ok, ^existing} = Denominations.merge_request(scope, request, existing)
      assert Repo.reload!(church).denomination_id == existing.id
      assert Denominations.get_request!(request.id).status == :merged
    end
  end
end
