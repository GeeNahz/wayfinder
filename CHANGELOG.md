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
