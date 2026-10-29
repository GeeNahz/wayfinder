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
- `badge`, `card` and `modal` core components; `button` gains `secondary`, `ghost` and `danger` variants and a `size` option.
- `Layouts.admin` sidebar layout for the super admin portal, and a `width` option (`narrow` / `wide` / `full`) on `Layouts.app`.
- Leaflet 1.9.4 installed with pnpm (`assets/package.json`) plus shared map helpers in `assets/js/maps.js`; `mix assets.setup` / `assets.deploy` now run `pnpm install`.
- Database tables and Ecto schemas for `denominations`, `denomination_requests`, `churches`, `activities`, `church_tokens` and `edit_requests`; `churches.owner_id` is a nullable link to `users`, reserved for future church owners.
- `Church` changesets: a church needs either a listed denomination or a requested denomination name, websites get `https://` added automatically, and the contact email can only be set at registration.
- `Activity` schema with a `days` array (1 = Monday … 7 = Sunday), so one activity can repeat on several days; the end time must be after the start time.
- `ChurchToken`: hashed, expiring secret links for email verification (48 h) and managing a church (7 days).
- `Wayfinder.Slug.slugify/1` helper.

### Changed
- Restyled core components, the app layout and the generated log-in, confirmation and settings pages with the new theme.
- Replaced the default Phoenix landing page with a temporary Wayfinder placeholder.

### Removed
- daisyUI and its theme plugin (`assets/vendor/daisyui*.js`).
