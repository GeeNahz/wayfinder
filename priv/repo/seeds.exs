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
