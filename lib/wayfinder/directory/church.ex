defmodule Wayfinder.Directory.Church do
  @moduledoc """
  A church listed in the directory.

  Status lifecycle:

      :unverified --(submitter clicks email link)--> :pending
      :pending    --(admin)--> :approved | :rejected
      :approved   <--(admin)--> :suspended

  Only `:approved` churches are shown to the public.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Wayfinder.Directory.Activity

  @statuses [:unverified, :pending, :approved, :rejected, :suspended]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "churches" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :phone, :string
    field :website, :string

    field :contact_email, :string
    field :email_verified_at, :utc_datetime

    field :address_line1, :string
    field :address_line2, :string
    field :city, :string
    field :region, :string
    field :postal_code, :string
    field :country, :string
    field :latitude, :float
    field :longitude, :float

    field :status, Ecto.Enum, values: @statuses, default: :unverified
    field :rejection_reason, :string
    field :approved_at, :utc_datetime
    field :last_edited_at, :utc_datetime

    field :requested_denomination, :string
    belongs_to :denomination, Wayfinder.Denominations.Denomination
    belongs_to :denomination_request, Wayfinder.Denominations.DenominationRequest

    # Reserved for future church-owner accounts (see Directory.Policy).
    belongs_to :owner, Wayfinder.Accounts.User

    has_many :activities, Activity, on_replace: :delete, preload_order: [asc: :starts_at]

    # Filled in by "near me" searches; not stored in the database.
    field :distance_km, :float, virtual: true

    timestamps(type: :utc_datetime)
  end

  def statuses, do: @statuses

  # Fields people can fill in on the church form (registration, manage link, admin edit).
  @form_fields [
    :name,
    :description,
    :phone,
    :website,
    :address_line1,
    :address_line2,
    :city,
    :region,
    :postal_code,
    :country,
    :latitude,
    :longitude,
    :denomination_id,
    :requested_denomination
  ]

  @doc """
  Changeset for editing an existing church (manage link or admin).

  The contact email is deliberately not editable: it is the identity we
  send edit links to.
  """
  def form_changeset(church, attrs) do
    church
    |> cast(attrs, @form_fields)
    |> update_change(:name, &String.trim/1)
    |> validate_required([:name, :address_line1, :city, :country, :latitude, :longitude],
      message: "can't be blank"
    )
    |> validate_length(:name, max: 160)
    |> validate_length(:description, max: 2000)
    |> validate_length(:phone, max: 40)
    |> validate_number(:latitude, greater_than_or_equal_to: -90, less_than_or_equal_to: 90)
    |> validate_number(:longitude, greater_than_or_equal_to: -180, less_than_or_equal_to: 180)
    |> normalize_website()
    |> validate_denomination()
    |> cast_assoc(:activities,
      with: &Activity.changeset/2,
      # These two params let the form add, reorder and remove activity rows.
      sort_param: :activities_sort,
      drop_param: :activities_drop
    )
    |> foreign_key_constraint(:denomination_id)
    |> check_constraint(:denomination_id, name: :denomination_chosen_or_requested)
  end

  @doc """
  Changeset for a brand new church submitted by the public.
  """
  def registration_changeset(church, attrs) do
    church
    |> form_changeset(attrs)
    |> cast(attrs, [:contact_email])
    |> validate_required([:contact_email], message: "can't be blank")
    |> update_change(:contact_email, &String.trim/1)
    |> validate_format(:contact_email, ~r/^[^@,;\s]+@[^@,;\s]+\.[^@,;\s]+$/,
      message: "must be a valid email address"
    )
    |> validate_length(:contact_email, max: 160)
    |> put_slug()
    |> unique_constraint(:slug)
  end

  # Picking a listed denomination wins; otherwise a requested name is needed.
  defp validate_denomination(changeset) do
    chosen = get_field(changeset, :denomination_id)
    requested = get_field(changeset, :requested_denomination)

    cond do
      chosen ->
        put_change(changeset, :requested_denomination, nil)

      is_binary(requested) and String.trim(requested) != "" ->
        changeset
        |> update_change(:requested_denomination, &String.trim/1)
        |> validate_length(:requested_denomination, max: 120)

      true ->
        add_error(changeset, :denomination_id, "choose a denomination or tell us yours")
    end
  end

  # Accept "example.org" and store it as "https://example.org".
  defp normalize_website(changeset) do
    update_change(changeset, :website, fn
      nil ->
        nil

      website ->
        website = String.trim(website)

        if website == "" or String.starts_with?(website, ["http://", "https://"]),
          do: website,
          else: "https://" <> website
    end)
    |> validate_format(:website, ~r/^https?:\/\/[^\s]+\.[^\s]+$/, message: "must be a valid URL")
  end

  # e.g. "Grace Chapel" => "grace-chapel-4f9a1c" (the suffix keeps slugs unique)
  defp put_slug(changeset) do
    if get_field(changeset, :slug) do
      changeset
    else
      name = get_field(changeset, :name) || "church"
      suffix = :crypto.strong_rand_bytes(3) |> Base.encode16(case: :lower)
      put_change(changeset, :slug, "#{Wayfinder.Slug.slugify(name)}-#{suffix}")
    end
  end

  @doc "A one-line address, e.g. for map popups."
  def full_address(%__MODULE__{} = church) do
    [
      church.address_line1,
      church.address_line2,
      church.city,
      church.region,
      church.postal_code,
      church.country
    ]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join(", ")
  end

  @doc "The denomination name to display (the requested one until it's resolved)."
  def denomination_name(%__MODULE__{denomination: %{name: name}}), do: name
  def denomination_name(%__MODULE__{requested_denomination: name}) when is_binary(name), do: name
  def denomination_name(_church), do: nil
end
