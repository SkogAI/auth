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

## Auth CLI Commands

The `./auth` binary provides these commands:

### Core Commands
- `./auth migrate` - Migrate database structures (creates tables, adds columns/indexes)
- `./auth serve` - Start API server
- `./auth version` - Show version information
- `./auth admin` - Admin operations (createuser, deleteuser)

### Global Flags
- `-c, --config <file>` - Load configuration from file (e.g., `-c .env`)
- `-d, --config-dir <dir>` - Directory with sorted config files to watch for changes

### Examples
```bash
# Run migrations with specific config
./auth migrate -c .env

# Start server with config
./auth serve -c .env

# Create admin user
./auth admin createuser -a authenticated
```

## Make Commands

- `make build` - Build auth binary
- `make migrate_dev` - Run migrations
- `make dev` - Start Docker containers
- `make down` - Stop Docker containers
- `make docker-build` - Full rebuild with migrations
