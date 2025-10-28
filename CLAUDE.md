# Supabase Auth - Fork

## Project Status

This is a **fork** of [Supabase Auth](https://github.com/supabase/auth) with custom modifications:

- Changed source code to temporarily fix SAML nil pointer bug in `internal/conf/saml.go`
- Custom build scripts in `.claude/scripts/`

**Note**: Do not merge upstream changes without careful review - we've diverged from mainline and want to get back as soon as possible.

## Quick Start

### Build and Run (Native Mode - port 9998)

```bash
./.claude/scripts/local/build.sh  # Format, vet, lint, build
./auth migrate -c .env            # Run database migrations
./auth serve -c .env              # Start server
```

### Docker Mode (port 9999)

```bash
./.claude/scripts/container/build.sh  # First time: builds, runs migrations, stops
./.claude/scripts/container/dev.sh    # Start containers
./.claude/scripts/container/down.sh   # Stop containers
```

## Configuration

- `.env` - Complete working configuration (85+ variables)
- `.env.docker` - Docker-specific overrides ONLY (DATABASE_URL, paths)
- `example.env` - Template with comments

Docker sources `.env` first, then applies `.env.docker` overrides.

## Database

**Native (port 9998):**

- Host: `localhost:5432`
- User: `supabase_auth_admin` / Password: `root`
- Connect: `PGPASSWORD=root psql -h localhost -U supabase_auth_admin -d postgres`

**Docker (port 9999):**

- Host (external): `localhost:54321`
- Host (internal): `postgres:5432`
- User: `supabase_auth_admin` / Password: `root`
- Connect: `PGPASSWORD=root psql -h localhost -p 54321 -U supabase_auth_admin -d postgres`

## Migrations

61 migrations covering:

- Initial schema (users, identities, sessions)
- OAuth/SAML support
- MFA/WebAuthn
- Latest: Sept 2025

Migrations are **idempotent** - safe to re-run.

## Scripts Overview

### Local Development (`.claude/scripts/local/`)

- `build.sh` - Format + vet + staticcheck + build + verify

### Container Operations (`.claude/scripts/container/`)

- `build.sh` - Full rebuild: build images, run migrations, stop
- `dev.sh` - Start containers with hot-reload
- `down.sh` - Stop containers
- `test.sh` - Run tests in containers
- `clean.sh` - Remove containers and volumes

## Auth CLI

```bash
./auth migrate [-c .env]           # Run migrations
./auth serve [-c .env]             # Start server
./auth version                     # Show version
./auth admin createuser [flags]    # Create admin user
```

## Development Notes

- Go 1.23.7
- PostgreSQL 15
- CGO disabled (statically linked binaries)
