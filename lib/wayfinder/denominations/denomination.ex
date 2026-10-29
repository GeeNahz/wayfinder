defmodule Wayfinder.Denominations.Denomination do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "denominations" do
    field :name, :string
    field :slug, :string
    field :description, :string
    # When set, the denomination is hidden from the public registration form.
    field :archived_at, :utc_datetime

    has_many :churches, Wayfinder.Directory.Church

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(denomination, attrs) do
    denomination
    |> cast(attrs, [:name, :description])
    |> update_change(:name, &String.trim/1)
    |> validate_required([:name])
    |> validate_length(:name, max: 120)
    |> validate_length(:description, max: 1000)
    |> put_slug()
    |> unique_constraint(:name)
    |> unique_constraint(:slug, message: "is too similar to an existing denomination")
  end

  # The slug always follows the name.
  defp put_slug(changeset) do
    case get_change(changeset, :name) do
      nil -> changeset
      name -> put_change(changeset, :slug, Wayfinder.Slug.slugify(name))
    end
  end

  def archived?(%__MODULE__{archived_at: archived_at}), do: archived_at != nil
end
