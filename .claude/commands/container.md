# Container Development Operations

Manage Docker container operations for the Supabase Auth service (Docker Mode - port 9999).

## Available Operations

- **dev** - Start development containers
- **down** - Stop development containers
- **build** - Force full rebuild with migrations (first-time setup)
- **test** - Run tests in containers
- **clean** - Remove containers and volumes

## Task

1. Ask the user which operation to run (if not specified in the request)
2. Execute the corresponding script: `.claude/scripts/container/{operation}.sh`
3. Report the results

## Examples

User: "start containers"
→ Run `.claude/scripts/container/dev.sh`

User: "rebuild everything"
→ Run `.claude/scripts/container/build.sh`

User: "run container tests"
→ Run `.claude/scripts/container/test.sh`

## Scripts Location

All scripts are in `.claude/scripts/container/`:
- `dev.sh` - Start containers (`docker-compose up`)
- `down.sh` - Stop containers
- `build.sh` - Full rebuild: build images, run migrations, stop
- `test.sh` - Run tests in containers with migrations
- `clean.sh` - Remove containers and volumes

## Context

- Port: 9999
- Database (external): `localhost:54321`
- Database (internal): `postgres:5432`
- User: `supabase_auth_admin:root`
- Config: `.env` + `.env.docker` overrides
- Compose file: `docker-compose-dev.yml`

## Typical Workflow

1. **First time**: `./.claude/scripts/container/build.sh`
2. **Daily dev**: `./.claude/scripts/container/dev.sh`
3. **Shutdown**: `./.claude/scripts/container/down.sh`

You can also run scripts directly: `./.claude/scripts/container/dev.sh`
