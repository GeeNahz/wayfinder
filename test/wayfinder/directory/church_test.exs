defmodule Wayfinder.Directory.ChurchTest do
  use Wayfinder.DataCase, async: true

  alias Wayfinder.Directory.Church

  @valid_attrs %{
    "name" => "Grace Chapel",
    "address_line1" => "1 Hope Street",
    "city" => "Lagos",
    "country" => "Nigeria",
    "latitude" => "6.5244",
    "longitude" => "3.3792",
    "requested_denomination" => "Grace Fellowship",
    "contact_email" => "pastor@example.com",
    "activities" => %{
      "0" => %{"name" => "Sunday Service", "days" => ["", "7"], "starts_at" => "09:00"}
    }
  }

  describe "registration_changeset/2" do
    test "is valid with the required fields" do
      changeset = Church.registration_changeset(%Church{}, @valid_attrs)

      assert changeset.valid?
      assert get_field(changeset, :slug) =~ ~r/^grace-chapel-[a-f0-9]{6}$/
      assert [%{days: [7]}] = get_field(changeset, :activities)
    end

    test "requires a denomination or a requested denomination" do
      attrs = Map.delete(@valid_attrs, "requested_denomination")
      changeset = Church.registration_changeset(%Church{}, attrs)

      assert "choose a denomination or tell us yours" in errors_on(changeset).denomination_id
    end

    test "a chosen denomination clears the requested one" do
      attrs = Map.put(@valid_attrs, "denomination_id", Ecto.UUID.generate())
      changeset = Church.registration_changeset(%Church{}, attrs)

      assert get_field(changeset, :requested_denomination) == nil
    end

    test "validates email and coordinates" do
      attrs = %{@valid_attrs | "contact_email" => "nope", "latitude" => "120"}
      errors = errors_on(Church.registration_changeset(%Church{}, attrs))

      assert errors.contact_email == ["must be a valid email address"]
      assert errors.latitude == ["must be less than or equal to 90"]
    end

    test "adds https:// to websites without a scheme" do
      attrs = Map.put(@valid_attrs, "website", "gracechapel.org")
      changeset = Church.registration_changeset(%Church{}, attrs)

      assert get_field(changeset, :website) == "https://gracechapel.org"
    end
  end

  describe "form_changeset/2" do
    test "does not allow changing the contact email" do
      church = %Church{contact_email: "pastor@example.com"}
      changeset = Church.form_changeset(church, Map.put(@valid_attrs, "contact_email", "x@y.com"))

      assert get_field(changeset, :contact_email) == "pastor@example.com"
    end
  end

  test "full_address/1 skips blank parts" do
    church = %Church{address_line1: "1 Hope St", address_line2: "", city: "Lagos", country: "NG"}
    assert Church.full_address(church) == "1 Hope St, Lagos, NG"
  end
end
