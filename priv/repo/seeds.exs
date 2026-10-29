# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Wayfinder.Repo.insert!(%Wayfinder.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Wayfinder.Accounts

# --- Super admin --------------------------------------------------------------
# In production set ADMIN_EMAIL and ADMIN_PASSWORD (12+ chars). The dev
# defaults below are only for local use.
admin_email = System.get_env("ADMIN_EMAIL", "admin@wayfinder.local")
admin_password = System.get_env("ADMIN_PASSWORD", "change-me-please")

if Accounts.get_user_by_email(admin_email) do
  IO.puts("Super admin #{admin_email} already exists, skipping.")
else
  {:ok, _admin} = Accounts.create_super_admin(admin_email, admin_password)
  IO.puts("Created super admin #{admin_email}")
end

alias Wayfinder.{Denominations, Repo}
alias Wayfinder.Directory.Church

# --- Denominations ------------------------------------------------------------
# A starting list; the admin can add, rename or archive these later.
denominations =
  for name <- [
        "Anglican",
        "Baptist",
        "Catholic",
        "Lutheran",
        "Methodist",
        "Non-denominational",
        "Orthodox",
        "Pentecostal",
        "Presbyterian",
        "Other"
      ],
      into: %{} do
    denomination =
      Denominations.get_denomination_by_slug(Wayfinder.Slug.slugify(name)) ||
        elem(Denominations.create_denomination(%{name: name}), 1)

    {name, denomination}
  end

IO.puts("Denominations ready (#{map_size(denominations)})")

# --- Sample churches (development only) ---------------------------------------
if Mix.env() == :dev do
  samples = [
    %{
      "name" => "Cathedral Church of Christ",
      "denomination" => "Anglican",
      "address_line1" => "29 Marina",
      "city" => "Lagos Island",
      "region" => "Lagos",
      "country" => "Nigeria",
      "latitude" => 6.4523,
      "longitude" => 3.3923,
      "activities" => [
        {"Holy Communion", [7], "07:00", "08:30"},
        {"Morning Service", [7], "09:00", "11:00"},
        {"Midweek Prayer", [3], "18:00", "19:00"}
      ]
    },
    %{
      "name" => "First Baptist Church Ikeja",
      "denomination" => "Baptist",
      "address_line1" => "8 Obafemi Awolowo Way",
      "city" => "Ikeja",
      "region" => "Lagos",
      "country" => "Nigeria",
      "latitude" => 6.6018,
      "longitude" => 3.3515,
      "activities" => [
        {"Sunday School", [7], "08:00", "09:00"},
        {"Worship Service", [7], "09:00", "11:30"},
        {"Bible Study", [3], "18:00", "19:30"},
        {"Youth Fellowship", [5], "17:00", nil}
      ]
    },
    %{
      "name" => "Holy Cross Cathedral",
      "denomination" => "Catholic",
      "address_line1" => "1 Catholic Mission Street",
      "city" => "Lagos Island",
      "region" => "Lagos",
      "country" => "Nigeria",
      "latitude" => 6.4541,
      "longitude" => 3.3947,
      "activities" => [
        {"Mass", [1, 2, 3, 4, 5], "06:30", "07:15"},
        {"Sunday Mass (English)", [7], "08:00", "09:30"},
        {"Sunday Mass (Yoruba)", [7], "10:00", "11:30"}
      ]
    },
    %{
      "name" => "Living Faith Chapel Lekki",
      "denomination" => "Pentecostal",
      "address_line1" => "Admiralty Way",
      "city" => "Lekki",
      "region" => "Lagos",
      "country" => "Nigeria",
      "latitude" => 6.4474,
      "longitude" => 3.4723,
      "activities" => [
        {"First Service", [7], "07:00", "09:00"},
        {"Second Service", [7], "09:00", "11:00"},
        {"Covenant Hour of Prayer", [1, 2, 3, 4, 5, 6], "06:00", "07:00"}
      ]
    },
    %{
      "name" => "Wesley Methodist Church",
      "denomination" => "Methodist",
      "address_line1" => "Herbert Macaulay Way",
      "city" => "Yaba",
      "region" => "Lagos",
      "country" => "Nigeria",
      "latitude" => 6.5095,
      "longitude" => 3.3711,
      "activities" => [
        {"Morning Worship", [7], "08:30", "10:30"},
        {"Choir Practice", [6], "16:00", "18:00"}
      ]
    }
  ]

  for sample <- samples, !Repo.get_by(Church, name: sample["name"]) do
    activities =
      sample["activities"]
      |> Enum.with_index()
      |> Map.new(fn {{name, days, starts_at, ends_at}, index} ->
        {to_string(index),
         %{"name" => name, "days" => days, "starts_at" => starts_at, "ends_at" => ends_at}}
      end)

    params =
      sample
      |> Map.drop(["denomination"])
      |> Map.merge(%{
        "denomination_id" => denominations[sample["denomination"]].id,
        "contact_email" => "sample@wayfinder.local",
        "activities" => activities
      })

    %Church{}
    |> Church.registration_changeset(params)
    |> Ecto.Changeset.change(
      status: :approved,
      email_verified_at: DateTime.utc_now(:second),
      approved_at: DateTime.utc_now(:second)
    )
    |> Repo.insert!()
  end

  IO.puts("Sample churches ready")
end
