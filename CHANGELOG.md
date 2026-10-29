# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Phoenix 1.8 / LiveView 1.2 / PostgreSQL application scaffold for Wayfinder.
- `CHANGELOG.md` following Keep a Changelog.
- Email/password + magic-link authentication generated with `phx.gen.auth` (`/users/log-in`, `/users/settings`); public sign-up is disabled.
- `role` column on `users` (`super_admin` | `owner`, default `owner`) and `Accounts.create_super_admin/2`; `owner` is reserved for future church-owner accounts.
- `/admin` live session guarded by the `:require_super_admin` on_mount hook, with a placeholder `Admin.DashboardLive`; super admins are redirected there after logging in.
- Seed for the super admin, read from `ADMIN_EMAIL` / `ADMIN_PASSWORD`.
- Custom Tailwind design tokens (`bg-surface`, `text-muted`, `border-line`, `bg-brand`, …) with light and dark themes in `assets/css/app.css`.
- `badge`, `card` and `modal` core components; `button` gains `secondary`, `ghost` and `danger` variants, a `size` option and `target`/`rel` attributes.
- `Layouts.admin` sidebar layout for the super admin portal, and a `width` option (`narrow` / `wide` / `full`) on `Layouts.app`.
- Leaflet 1.9.4 installed with pnpm (`assets/package.json`) plus shared map helpers in `assets/js/maps.js`; `mix assets.setup` / `assets.deploy` now run `pnpm install`.
- Database tables and Ecto schemas for `denominations`, `denomination_requests`, `churches`, `activities`, `church_tokens` and `edit_requests`; `churches.owner_id` is a nullable link to `users`, reserved for future church owners.
- `Church` changesets: a church needs either a listed denomination or a requested denomination name, websites get `https://` added automatically, and the contact email can only be set at registration.
- `Activity` schema with a `days` array (1 = Monday … 7 = Sunday), so one activity can repeat on several days; the end time must be after the start time.
- `ChurchToken`: hashed, expiring secret links for email verification (48 h) and managing a church (7 days).
- `Wayfinder.Slug.slugify/1` helper.
- `Wayfinder.Denominations` context: denomination CRUD and archiving, church counts, and denomination requests that can be approved as a new denomination or merged into an existing one (moving the waiting churches onto it).
- `Wayfinder.Directory` context:
  - registration saves an unverified church and emails a verification link; verifying sets it to `pending` and links a shared denomination request;
  - public search by text, denomination, weekday and distance ("near me");
  - manage-link tokens, church edits, and admin approve/reject/suspend/delete with notification emails.
- `Wayfinder.EditRequests` context: stores an edit request only when the email matches the church's verified contact email (the response is the same either way); granting it emails a 7-day manage link to the contact email.
- `Wayfinder.Directory.Policy.can_manage?/2`: the single authorization check for super admins, manage links and future church owners.
- `Wayfinder.Turnstile.verify/2`: server-side Cloudflare Turnstile token check (Cloudflare test keys in dev).
- `Wayfinder.Geocoding` behaviour with an OpenStreetMap Nominatim implementation for address search.
- `Wayfinder.Directory.ChurchNotifier` emails: verification link, approved, rejected (with reason), and edit link granted.
- `Wayfinder.Directory.Janitor`: an hourly process that deletes churches left unverified for more than 48 h and expired tokens.
- `:mail_from` setting (`Wayfinder.Mailer.default_from/0`), used by every email.
- Public "Register a church" page (`/churches/new`, `ChurchLive.Register`) covering details, denomination (pick from the list or request a new one), address with "Find on map", a draggable map pin, repeatable weekly activities with day pickers, the contact email and a Cloudflare Turnstile spam check.
- `GET /churches/verify/:token` confirms the submitter's email and moves the church to admin review.
- Shared `ChurchFormComponents.church_fields/1` and `ChurchLive.FormHelpers`, reused later by the manage-link and admin edit pages.
- `MapPicker` and `Turnstile` JavaScript hooks (`assets/js/hooks/`); the Turnstile script is loaded from Cloudflare at runtime because it can't be bundled.
- `WayfinderWeb.ClientIp`, which reads the visitor IP from the LiveView connection (`x-forwarded-for` behind Cloudflare); the live socket now passes `:peer_data` and `:x_headers` connect info.
- "Register a church" call-to-action in the site header.
- The home page (`/`, `DirectoryLive`) is now a map and list of approved churches. Filters (name/city text, denomination, weekday) are kept in the URL, and "Near me" uses browser geolocation to sort results by distance.
- Public church page (`/churches/:slug`, `ChurchLive.Show`) with the weekly schedule grouped by day, a location map, and "Get directions" / "Open in Google Maps" links.
- `ChurchMap` and `NearMe` JavaScript hooks; map popups are built with DOM APIs so names typed by the public can't inject HTML.
- `WayfinderWeb.ChurchHelpers` for formatting times, distances, schedules and map markers.
- `Directory.get_public_church_by_slug!/1`, which returns a 404 for churches that aren't approved.
- "Request to edit" modal on the church page (email, optional message, Turnstile). It shows the same confirmation whether or not the email matches.
- Manage-link edit page (`/churches/:slug/manage/:token`, `ChurchLive.Manage`) reusing the church form. Edits go live immediately, and expired, revoked or mismatched links show an explanation instead.
- `Directory.get_church_by_slug/1`, and `FormHelpers.denomination_options/1` keeps a church's archived denomination selectable.

### Changed
- Restyled core components, the app layout and the generated log-in, confirmation and settings pages with the new theme.
- Replaced the default Phoenix landing page with the church directory (removed `PageController`).

### Fixed
- Clearing a trimmed text field (church name, contact email, denomination name, edit-request email) no longer crashes the changeset with `FunctionClauseError` in `String.trim/1`.

### Removed
- daisyUI and its theme plugin (`assets/vendor/daisyui*.js`).
