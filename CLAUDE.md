# Supabase Auth - Development Setup

## Configuration Philosophy

- `.env` = Complete working configuration for auth service
- `.env.docker` = Minimal overrides ONLY for Docker-specific differences (hostname, paths)
- Docker sources `.env` first, then applies `.env.docker` overrides

## Development Modes

### Native Mode (port 9998)
```bash
./auth migrate  # Run migrations
./auth serve    # Start service
```

### Docker Mode (port 9999)
```bash
make docker-build  # First time: builds, runs migrations, stops
make dev           # Start containers
```

## Database

### Native: Local PostgreSQL
- Host: `localhost:5432`
- User: `supabase_auth_admin:root`
- Connect: `PGPASSWORD=root psql -h localhost -U supabase_auth_admin -d postgres`

### Docker: Container PostgreSQL
- Host (from outside): `localhost:54321` (mapped to avoid local postgres conflict)
- Host (inside Docker): `postgres:5432`
- User: `supabase_auth_admin:root`
- Connect: `PGPASSWORD=root psql -h localhost -p 54321 -U supabase_auth_admin -d postgres`

## Migrations

Migrations are **idempotent** - run `./auth migrate` anytime, it applies only missing migrations.

## Make Commands

- `make build` - Build auth binary
- `make migrate_dev` - Run migrations
- `make dev` - Start Docker containers
- `make down` - Stop Docker containers
- `make docker-build` - Full rebuild with migrations
