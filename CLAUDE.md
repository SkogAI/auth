# Supabase Auth - Development Setup

## First-Time Setup

```bash
make docker-build  # Builds containers, starts postgres, runs migrations, stops
make dev           # Starts the development environment
```

## Make Commands Workflow

Based on `Makefile`:

- `make docker-build` - Full rebuild: builds containers with `--no-cache`, starts postgres, runs `make migrate_dev`, then stops
- `make dev` - Starts containers (requires `docker-build` to have been run first)
- `make down` - Stops containers
- `make docker-clean` - Removes containers (does NOT remove volumes)

## Important

- `make dev` does NOT handle setup/migrations - it only runs `docker compose up`
- First-time setup MUST run `make docker-build` before `make dev`
- To fully reset (including DB): stop containers, remove volume `auth_postgres_data`, run `make docker-build`

## Configuration Files

- `.env.docker` - Used by Docker containers (mounted via docker-compose-dev.yml)
- `.env` - Local development config (also mounted, can override .env.docker values)
- `docker-compose-dev.yml` - Container orchestration

## Database

### Docker PostgreSQL (for auth project)

- Container: `auth-postgres-1`
- **Host**: `localhost`
- **Port**: `54321` (mapped to avoid conflict with local PostgreSQL)
- **User**: `supabase_auth_admin`
- **Password**: `root`
- **Database**: `postgres`

**Connection command:**
```bash
PGPASSWORD=root psql --host localhost --port 54321 --user supabase_auth_admin --dbname postgres
```

### Local System PostgreSQL (if running)

- **Socket**: `/run/postgresql/.s.PGSQL.5432`
- **Port**: `5432`
- **User**: `postgres` (no password via socket)

**Connection command:**
```bash
psql --list  # Uses socket by default
# or
psql --host localhost --port 5432 --user postgres
```

**Note:** Port 54321 is used for Docker to avoid conflicts with local PostgreSQL on port 5432.

## Auth Service

- Runs on port `9999`
- Health check: `http://localhost:9999/health`
- Auto-reloads on file changes via CompileDaemon
