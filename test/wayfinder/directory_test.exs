defmodule Wayfinder.DirectoryTest do
  use Wayfinder.DataCase, async: true

  import Swoosh.TestAssertions
  import Wayfinder.DirectoryFixtures

  alias Wayfinder.Directory
  alias Wayfinder.Directory.{Church, ChurchToken}
  alias Wayfinder.Repo

  describe "register_church/2" do
    test "saves an unverified church and emails a verification link" do
      {church, token} = registered_church_fixture(%{"requested_denomination" => "New Church"})

      assert church.status == :unverified
      assert church.email_verified_at == nil
      assert [%{name: "Sunday Service", days: [7]}] = Repo.preload(church, :activities).activities

      assert_email_sent(fn email ->
        assert email.to == [{"", church.contact_email}]
        assert email.text_body =~ "http://example.com/verify/#{token}"
      end)
    end

    test "returns the changeset when invalid" do
      assert {:error, changeset} = Directory.register_church(%{}, fn _ -> "url" end)
      assert errors_on(changeset).name == ["can't be blank"]
      assert_no_email_sent()
    end
  end

  describe "verify_church/1" do
    test "marks the church pending and creates a denomination request" do
      {church, token} = registered_church_fixture(%{"requested_denomination" => "New Church"})

      assert {:ok, verified} = Directory.verify_church(token)
      assert verified.id == church.id
      assert verified.status == :pending
      assert verified.email_verified_at

      assert Repo.preload(verified, :denomination_request).denomination_request.name ==
               "New Church"
    end

    test "links only to an existing denomination when one was chosen" do
      {_church, token} =
        registered_church_fixture(%{"denomination_id" => denomination_fixture().id})

      assert {:ok, verified} = Directory.verify_church(token)
      assert verified.denomination_request_id == nil
    end

    test "links can only be used once" do
      {_church, token} = registered_church_fixture(%{"requested_denomination" => "X"})

      assert {:ok, _church} = Directory.verify_church(token)
      assert :error = Directory.verify_church(token)
    end

    test "rejects bad and expired tokens" do
      {church, token} = registered_church_fixture(%{"requested_denomination" => "X"})
      assert :error = Directory.verify_church("not-a-token")

      Repo.update_all(ChurchToken, set: [expires_at: DateTime.add(DateTime.utc_now(), -1, :hour)])
      assert :error = Directory.verify_church(token)
      assert Repo.reload!(church).status == :unverified
    end
  end

  describe "list_public_churches/1" do
    test "only lists approved churches" do
      approved = church_fixture()
      church_fixture(%{}, :pending)
      church_fixture(%{}, :suspended)

      assert [%Church{id: id}] = Directory.list_public_churches()
      assert id == approved.id
    end

    test "filters by text, denomination and day" do
      baptist = denomination_fixture(%{name: "Baptist"})

      wednesday =
        church_fixture(%{
          "name" => "Hope Baptist",
          "city" => "Ibadan",
          "denomination_id" => baptist.id,
          "activities" => %{
            "0" => %{"name" => "Bible Study", "days" => ["3"], "starts_at" => "18:00"}
          }
        })

      _sunday = church_fixture(%{"name" => "Grace Chapel", "city" => "Lagos"})

      assert [%{id: id}] = Directory.list_public_churches(%{"q" => "ibad"})
      assert id == wednesday.id
      assert [%{id: ^id}] = Directory.list_public_churches(%{"denomination" => "baptist"})
      assert [%{id: ^id}] = Directory.list_public_churches(%{"day" => 3})
      assert Directory.list_public_churches(%{"day" => 3, "q" => "grace"}) == []
    end

    test "treats % and _ in searches as plain text" do
      church_fixture(%{"name" => "Grace Chapel"})
      assert Directory.list_public_churches(%{"q" => "%"}) == []
    end

    test "sorts by distance when given a location" do
      far = church_fixture(%{"name" => "Far", "latitude" => "9.0765", "longitude" => "7.3986"})
      near = church_fixture(%{"name" => "Near", "latitude" => "6.60", "longitude" => "3.35"})

      assert [first, second] = Directory.list_public_churches(%{"near" => {6.5244, 3.3792}})
      assert first.id == near.id
      assert second.id == far.id
      assert first.distance_km < 10
      assert second.distance_km > 400
    end
  end

  describe "moderation" do
    test "approve_church/2 publishes and emails the submitter" do
      church = church_fixture(%{}, :pending)

      assert {:ok, church} = Directory.approve_church(church, &"http://example.com/#{&1.slug}")
      assert church.status == :approved
      assert church.approved_at
      assert_email_sent(subject: "#{church.name} is now on Wayfinder")
    end

    test "approve_church/2 waits for a requested denomination" do
      church = church_fixture(%{"requested_denomination" => "Unknown"}, :pending)
      assert {:error, :denomination_pending} = Directory.approve_church(church, & &1.slug)
    end

    test "reject_church/2 needs a reason" do
      church = church_fixture(%{}, :pending)

      assert {:error, changeset} = Directory.reject_church(church, nil)
      assert errors_on(changeset).rejection_reason == ["please give a reason"]

      assert {:ok, church} = Directory.reject_church(church, "Duplicate listing")
      assert church.status == :rejected
      assert_email_sent(fn email -> assert email.text_body =~ "Duplicate listing" end)
    end

    test "suspend and unsuspend" do
      church = church_fixture()
      assert {:ok, %{status: :suspended} = church} = Directory.suspend_church(church)
      assert {:ok, %{status: :approved}} = Directory.unsuspend_church(church)
    end

    test "count_churches_by_status/0 ignores unverified churches" do
      church_fixture(%{}, :pending)
      church_fixture(%{}, :approved)
      registered_church_fixture(%{"requested_denomination" => "X"})

      assert Directory.count_churches_by_status() == %{pending: 1, approved: 1}
    end

    test "list_churches/1 filters by status and text" do
      pending = church_fixture(%{"name" => "Pending Place"}, :pending)
      church_fixture(%{"name" => "Approved Place"})

      assert [%{id: id}] = Directory.list_churches(%{"status" => "pending"})
      assert id == pending.id
      assert [%{id: ^id}] = Directory.list_churches(%{"q" => "pending pl"})
      assert length(Directory.list_churches(%{"status" => "bogus"})) == 2
    end
  end

  describe "manage links and editing" do
    test "a manage token resolves to its church until revoked" do
      church = church_fixture()
      token = Directory.create_manage_token(church)

      assert Directory.get_church_by_manage_token(token).id == church.id
      assert Directory.get_church_by_manage_token("nonsense") == nil

      assert Directory.revoke_manage_links(church) == 1
      assert Directory.get_church_by_manage_token(token) == nil
    end

    test "update_church/2 applies changes and records the edit time" do
      church = church_fixture()

      assert {:ok, updated} =
               Directory.update_church(church, %{
                 "name" => "Renamed",
                 "activities" => %{
                   "0" => %{"name" => "Prayer", "days" => ["1", "2"], "starts_at" => "06:00"}
                 }
               })

      assert updated.name == "Renamed"
      assert updated.last_edited_at
      assert [%{name: "Prayer", days: [1, 2]}] = updated.activities
    end
  end

  describe "housekeeping" do
    test "deletes unverified churches older than 48 hours" do
      {old, _token} = registered_church_fixture(%{"requested_denomination" => "X"})
      {recent, _token} = registered_church_fixture(%{"requested_denomination" => "X"})

      old
      |> Ecto.Changeset.change(inserted_at: DateTime.add(DateTime.utc_now(:second), -49, :hour))
      |> Repo.update!()

      assert Directory.delete_expired_unverified_churches() == 1
      refute Repo.get(Church, old.id)
      assert Repo.get(Church, recent.id)
    end

    test "deletes expired tokens" do
      church_fixture() |> Directory.create_manage_token()
      Repo.update_all(ChurchToken, set: [expires_at: DateTime.add(DateTime.utc_now(), -1, :hour)])

      assert Directory.delete_expired_tokens() == 1
    end
  end
end
