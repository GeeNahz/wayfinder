defmodule Wayfinder.Repo.Migrations.CreateDenominations do
  use Ecto.Migration

  def change do
    # Denominations are onboarded by the super admin. They are archived
    # (hidden from the public form) rather than deleted.
    create table(:denominations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      # citext = case-insensitive text, so "Baptist" and "baptist" clash
      add :name, :citext, null: false
      add :slug, :string, null: false
      add :description, :text
      add :archived_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:denominations, [:name])
    create unique_index(:denominations, [:slug])

    # A request to add a denomination that isn't listed yet. It is created
    # when a church that asked for it verifies its email.
    create table(:denomination_requests, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :citext, null: false
      add :status, :string, null: false, default: "pending"

      add :resolved_denomination_id,
          references(:denominations, type: :binary_id, on_delete: :nilify_all)

      add :resolved_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :resolved_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    # Only one *pending* request per name; old resolved ones can repeat.
    create unique_index(:denomination_requests, [:name],
             where: "status = 'pending'",
             name: :denomination_requests_pending_name_index
           )

    create index(:denomination_requests, [:status])
  end
end
