defmodule Wayfinder.Directory.ActivityTest do
  use Wayfinder.DataCase, async: true

  alias Wayfinder.Directory.Activity

  defp changeset(attrs), do: Activity.changeset(%Activity{}, attrs)

  test "valid activity repeated on several days" do
    changeset =
      changeset(%{"name" => "Bible Study", "days" => ["5", "3", "3"], "starts_at" => "18:00"})

    assert changeset.valid?
    assert get_field(changeset, :days) == [3, 5]
  end

  test "requires at least one valid day" do
    assert "pick at least one day" in errors_on(changeset(%{"days" => [""]})).days
    assert "has an invalid entry" in errors_on(changeset(%{"days" => ["8"]})).days
  end

  test "end time must be after the start time" do
    errors = errors_on(changeset(%{"starts_at" => "10:00", "ends_at" => "09:00"}))
    assert "must be after the start time" in errors.ends_at
  end

  test "days_label/1" do
    assert Activity.days_label([5, 3]) == "Wed, Fri"
  end
end
