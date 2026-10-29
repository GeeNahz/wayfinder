# Wayfinder

A church directory. Anyone can register a church with its location and weekly
activities; a platform super admin reviews submissions and manages
denominations; visitors find churches on a map.

Built with Phoenix 1.8, LiveView, PostgreSQL, Tailwind CSS v4 and Leaflet
(OpenStreetMap).

## Getting started

Requirements: Elixir 1.15+, PostgreSQL, and [pnpm](https://pnpm.io) (for the
Leaflet map library).

```sh
mix setup        # deps, database, seeds, pnpm install, assets
mix phx.server   # http://localhost:4000
```

The seeds create:

- a super admin: `admin@wayfinder.local` / `change-me-please` (dev only —
  set `ADMIN_EMAIL` / `ADMIN_PASSWORD` to choose your own)
- a starting list of denominations
- a few sample churches in Lagos (dev only)

Log in at `/users/log-in`; the admin portal is at `/admin`.
Emails sent in development show up at [`/dev/mailbox`](http://localhost:4000/dev/mailbox).

Run the checks before committing:

```sh
mix precommit    # compile (warnings as errors), format, tests
```

## How it works

### Registering a church

1. `/churches/new`: details, denomination (pick one, or type a new name to
   request it), address + map pin, weekly activities, contact email, and a
   Cloudflare Turnstile spam check.
2. The church is saved as **unverified** and a confirmation link is emailed.
   Unverified churches are deleted after 48 hours.
3. Opening the link (`/churches/verify/:token`) moves it to **pending**.
   A requested denomination becomes a *denomination request* for the admin.
4. The admin approves (or rejects) it. Approved churches appear on the map.

### Editing a church later (no accounts yet)

1. On the church page, "Request to edit" asks for the email it was
   registered with (+ Turnstile). The visitor always sees the same reply, so
   the form can't be used to discover emails; a request is only stored when
   the email matches.
2. The admin grants it under **Edit requests**, which emails a private
   7-day link (`/churches/:slug/manage/:token`) to the church's verified
   contact email. Edits made there go live immediately.

### Church statuses

```
unverified ──(email link)──► pending ──► approved ◄──► suspended
                                    └──► rejected
```

### Future church-owner accounts

`users.role` already supports `owner`, `churches.owner_id` links a church to
a user, and every "who may edit this church?" decision goes through
`Wayfinder.Directory.Policy.can_manage?/2`, which already allows a church's
owner. Adding owner sign-up later means letting owners log in and pointing
an edit page at that policy.

## Code map

| Where | What |
|---|---|
| `lib/wayfinder/directory.ex` | Churches: registration, verification, public search, moderation |
| `lib/wayfinder/denominations.ex` | Denominations and denomination requests |
| `lib/wayfinder/edit_requests.ex` | "Request to edit" flow |
| `lib/wayfinder/directory/` | Schemas (`Church`, `Activity`, `ChurchToken`), `Policy`, emails, hourly `Janitor` |
| `lib/wayfinder/turnstile.ex` | Server-side Cloudflare Turnstile check |
| `lib/wayfinder/geocoding.ex` | Address search behaviour (Nominatim implementation) |
| `lib/wayfinder_web/live/` | Public LiveViews (`DirectoryLive`, `ChurchLive.*`) and `admin/` |
| `lib/wayfinder_web/components/church_form_components.ex` | The church form, shared by register / manage / admin edit |
| `assets/js/hooks/` | Map, "near me" and Turnstile JavaScript hooks |

## Production

Environment variables (besides the usual `DATABASE_URL`, `SECRET_KEY_BASE`,
`PHX_HOST`):

| Variable | Purpose |
|---|---|
| `RESEND_API_KEY` | Sending email via [Resend](https://resend.com) |
| `MAIL_FROM` | Sender address, on a domain verified in Resend |
| `TURNSTILE_SITE_KEY` / `TURNSTILE_SECRET_KEY` | Cloudflare Turnstile keys |
| `NOMINATIM_USER_AGENT` | Identifies the app to OpenStreetMap's geocoder, e.g. `Wayfinder (admin@yourdomain.org)` |
| `ADMIN_EMAIL` / `ADMIN_PASSWORD` | The super admin created by `priv/repo/seeds.exs` |

Behind Cloudflare, it's also worth adding a WAF **rate limiting rule** for
`/churches/*` (e.g. a handful of requests per minute per IP) on top of
Turnstile.

Nominatim's free service allows about one request per second; if address
search becomes busy, swap in another provider by implementing the
`Wayfinder.Geocoding` behaviour and changing `config :wayfinder, :geocoder`.
