defmodule Wayfinder.Repo.Migrations.CreateChurches do
  use Ecto.Migration

  def change do
    create table(:churches, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text
      add :phone, :string
      add :website, :string

      # The submitter's email. It must be verified before the church is
      # reviewed, and edit links are only ever sent to this address.
      add :contact_email, :citext, null: false
      add :email_verified_at, :utc_datetime

      add :address_line1, :string, null: false
      add :address_line2, :string
      add :city, :string, null: false
      add :region, :string
      add :postal_code, :string
      add :country, :string, null: false
      add :latitude, :float, null: false
      add :longitude, :float, null: false

      # unverified -> pending -> approved | rejected; approved <-> suspended
      add :status, :string, null: false, default: "unverified"
      add :rejection_reason, :text
      add :approved_at, :utc_datetime
      add :last_edited_at, :utc_datetime

      # Either a known denomination, or the name of one the submitter asked us to add.
      add :denomination_id, references(:denominations, type: :binary_id, on_delete: :restrict)
      add :requested_denomination, :string

      add :denomination_request_id,
          references(:denomination_requests, type: :binary_id, on_delete: :nilify_all)

      # Not used yet: reserved for when church owners get their own accounts.
      add :owner_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:churches, [:slug])
    create index(:churches, [:status])
    create index(:churches, [:denomination_id])
    create index(:churches, [:denomination_request_id])
    create index(:churches, [:owner_id])
    create index(:churches, [:latitude, :longitude])

    create constraint(:churches, :denomination_chosen_or_requested,
             check: "denomination_id IS NOT NULL OR requested_denomination IS NOT NULL"
           )

    create constraint(:churches, :latitude_range, check: "latitude BETWEEN -90 AND 90")
    create constraint(:churches, :longitude_range, check: "longitude BETWEEN -180 AND 180")

    # Weekly activities. One row can repeat on several days, e.g. a Bible
    # study on Wednesdays and Fridays => days = [3, 5] (1 = Monday ... 7 = Sunday).
    create table(:activities, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :church_id, references(:churches, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :days, {:array, :integer}, null: false
      add :starts_at, :time, null: false
      add :ends_at, :time
      add :description, :text

      timestamps(type: :utc_datetime)
    end

    create index(:activities, [:church_id])
    # GIN index makes "which churches have something on day X" fast.
    create index(:activities, [:days], using: :gin)

    create constraint(:activities, :ends_after_start,
             check: "ends_at IS NULL OR ends_at > starts_at"
           )

    # One-time secret links (email verification and "manage church" links).
    # Only a hash of the token is stored; the raw token lives in the email.
    create table(:church_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :church_id, references(:churches, type: :binary_id, on_delete: :delete_all), null: false
      add :hashed_token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :citext, null: false
      add :expires_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:church_tokens, [:church_id])
    create unique_index(:church_tokens, [:context, :hashed_token])

    # "Please let me edit this church" requests, reviewed by the super admin.
    create table(:edit_requests, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :church_id, references(:churches, type: :binary_id, on_delete: :delete_all), null: false
      add :email, :citext, null: false
      add :message, :text
      add :status, :string, null: false, default: "pending"
      add :resolved_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :resolved_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:edit_requests, [:church_id])
    create index(:edit_requests, [:status])
  end
end
