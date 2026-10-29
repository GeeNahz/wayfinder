defmodule Wayfinder.EditRequestsTest do
  use Wayfinder.DataCase, async: true

  import Swoosh.TestAssertions
  import Wayfinder.AccountsFixtures
  import Wayfinder.DirectoryFixtures

  alias Wayfinder.Accounts.Scope
  alias Wayfinder.Directory
  alias Wayfinder.EditRequests

  setup do
    %{church: church_fixture(), scope: Scope.for_user(super_admin_fixture())}
  end

  describe "request_edit/2" do
    test "stores a request when the email matches (any case)", %{church: church} do
      email = String.upcase(church.contact_email)

      assert :ok =
               EditRequests.request_edit(church, %{"email" => email, "message" => "New times"})

      assert [request] = EditRequests.list_pending_edit_requests()
      assert request.church.id == church.id
      assert request.message == "New times"
    end

    test "silently ignores a non-matching email", %{church: church} do
      assert :ok = EditRequests.request_edit(church, %{"email" => "someone@else.com"})
      assert EditRequests.count_pending_edit_requests() == 0
    end

    test "keeps only one pending request per church", %{church: church} do
      assert :ok = EditRequests.request_edit(church, %{"email" => church.contact_email})
      assert :ok = EditRequests.request_edit(church, %{"email" => church.contact_email})
      assert EditRequests.count_pending_edit_requests() == 1
    end

    test "returns errors for an invalid form", %{church: church} do
      assert {:error, changeset} = EditRequests.request_edit(church, %{"email" => "nope"})
      assert errors_on(changeset).email == ["must be a valid email address"]
    end
  end

  describe "grant and reject" do
    setup %{church: church} do
      :ok = EditRequests.request_edit(church, %{"email" => church.contact_email})
      [request] = EditRequests.list_pending_edit_requests()
      %{request: request}
    end

    test "grant_edit_request/3 emails a working manage link to the contact email", %{
      church: church,
      request: request,
      scope: scope
    } do
      url_fun = fn church, token ->
        send(self(), {:manage_token, token})
        "http://example.com/churches/#{church.slug}/manage/#{token}"
      end

      assert {:ok, granted} = EditRequests.grant_edit_request(scope, request, url_fun)
      assert granted.status == :granted
      assert granted.resolved_by_id == scope.user.id

      assert_received {:manage_token, token}
      assert Directory.get_church_by_manage_token(token).id == church.id

      assert_email_sent(fn email ->
        assert email.to == [{"", church.contact_email}]
        assert email.text_body =~ "/manage/#{token}"
      end)
    end

    test "reject_edit_request/2", %{request: request, scope: scope} do
      assert {:ok, %{status: :rejected}} = EditRequests.reject_edit_request(scope, request)
      assert EditRequests.count_pending_edit_requests() == 0
      assert_no_email_sent()
    end
  end
end
