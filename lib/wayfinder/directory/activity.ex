defmodule Wayfinder.Directory.Activity do
  @moduledoc """
  A weekly activity, e.g. "Sunday Service, Sundays 9:00–11:00".

  `days` holds ISO weekday numbers: 1 = Monday ... 7 = Sunday, so one row can
  repeat on several days. Activities may overlap with each other.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @day_names %{
    1 => "Monday",
    2 => "Tuesday",
    3 => "Wednesday",
    4 => "Thursday",
    5 => "Friday",
    6 => "Saturday",
    7 => "Sunday"
  }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "activities" do
    field :name, :string
    field :days, {:array, :integer}, default: []
    field :starts_at, :time
    field :ends_at, :time
    field :description, :string

    belongs_to :church, Wayfinder.Directory.Church

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(activity, attrs) do
    activity
    |> cast(remove_blank_days(attrs), [:name, :days, :starts_at, :ends_at, :description])
    |> validate_required([:name, :starts_at])
    |> validate_length(:name, max: 120)
    |> validate_length(:description, max: 500)
    |> validate_days_present()
    |> validate_subset(:days, 1..7)
    |> update_change(:days, &(&1 |> Enum.uniq() |> Enum.sort()))
    |> validate_end_after_start()
    |> check_constraint(:ends_at,
      name: :ends_after_start,
      message: "must be after the start time"
    )
  end

  # Forms send an empty "" alongside the day checkboxes so that un-ticking
  # every box still submits the field. We drop those blanks before casting.
  defp remove_blank_days(%{"days" => days} = attrs) when is_list(days) do
    Map.put(attrs, "days", Enum.reject(days, &(&1 == "")))
  end

  defp remove_blank_days(attrs), do: attrs

  # validate_required/2 doesn't treat an empty list as missing, so check it ourselves.
  defp validate_days_present(changeset) do
    if get_field(changeset, :days) in [nil, []] do
      add_error(changeset, :days, "pick at least one day")
    else
      changeset
    end
  end

  defp validate_end_after_start(changeset) do
    starts_at = get_field(changeset, :starts_at)
    ends_at = get_field(changeset, :ends_at)

    if starts_at && ends_at && Time.compare(ends_at, starts_at) != :gt do
      add_error(changeset, :ends_at, "must be after the start time")
    else
      changeset
    end
  end

  @doc "All weekdays as `{number, name}` pairs, Monday first."
  def weekdays, do: Enum.map(1..7, &{&1, @day_names[&1]})

  def day_name(day), do: Map.fetch!(@day_names, day)

  @doc "Short label for a list of days, e.g. [3, 5] => \"Wed, Fri\"."
  def days_label(days) do
    days
    |> Enum.sort()
    |> Enum.map_join(", ", &String.slice(day_name(&1), 0, 3))
  end
end
