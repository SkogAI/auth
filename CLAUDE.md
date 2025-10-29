# Supabase Auth - Fork (Project claude.md)

## Critical Behavior (Project-Level)
- Inherits the organizational Critical Behavior rules from `~/.claude/claude.md`; project rules may add, but must not relax, those hard rules without an explicit, approved exception.
- Maintain context headroom of 10–20%; if the next step would drop below this headroom, pause and use the `/compact` template before proceeding.
- Stop-the-line triggers (project additions):
  - **Database migration failures or schema drift** - Migrations are idempotent; any failure indicates serious issue
  - **SAML configuration errors** - Security-critical; service fails to start if SAML private key invalid
  - **Auth token validation failures** - Core business logic; must not break
  - **Secrets/credentials in code or logs** - Auth service handles sensitive data
  - **Build failures (go fmt, go vet, staticcheck)** - Enforced by `.claude/scripts/local/build.sh`
- Always ask before (project additions):
  - **Merging upstream Supabase Auth changes** - We've diverged; careful review required
  - **Database schema changes** - 61 migrations in production; breaking changes affect users
  - **Environment variable changes** - 85+ vars in `.env`; coordinate with deployment
  - **Build script modifications** - Custom workflow in `.claude/scripts/`
  - **SAML configuration changes** - Affects Zitadel integration; requires metadata updates on both sides
- Never do:
  - **Merge upstream without review** - Fork has diverged; document all conflicts
  - **Disable CGO** - Already disabled; statically linked binaries required
  - **Skip migrations** - Always run `./auth migrate -c .env` before `serve`
  - **Commit `.env` or `.env.docker`** - Contains production secrets
  - **Bypass `staticcheck` or `go vet`** - Build script enforces these

## Scope
This is a **fork** of [Supabase Auth](https://github.com/supabase/auth) with custom modifications. We've diverged from mainline and want to get back as soon as possible.

**Custom modifications:**
- ~~Temporary fix for SAML nil pointer bug in `internal/conf/saml.go`~~ - REVERTED, no upstream bug exists
- Custom build scripts in `.claude/scripts/local/` and `.claude/scripts/container/`
- Dual-mode operation: Native (localhost DB) and Docker (containerized DB), both use **port 9999**
- **SAML Configuration**: Native SAML SP enabled with Zitadel as IdP

## Stack
### Languages/Runtimes + Versions
- **Primary language**: Go 1.23.7
- **Runtime version**: Go 1.23.7
- **Secondary languages**: N/A (pure Go service)

### Frameworks/Libraries
- **Web framework**: `github.com/go-chi/chi` (inferred from Supabase Auth)
- **Testing framework**: Go standard `testing` package
- **UI library**: N/A (API service)
- **State management**: N/A (API service)
- **Database/ORM**: PostgreSQL 15 with `pgx` driver, `golang-migrate` for migrations

### Package Manager/Build Tools
- **Package manager**: Go modules (`go.mod`)
- **Build tool**: Custom scripts (`.claude/scripts/local/build.sh`)
- **Bundler**: N/A (statically linked binary with CGO_ENABLED=0)
- **Task runner**: Bash scripts in `.claude/scripts/`

## Code Style
### Formatter + Config
- **Formatter tool**: `gofmt` and `go fmt`
- **Config file location**: Default Go formatting (no config file)
- **Pre-commit hooks**: None currently; enforced by `.claude/scripts/local/build.sh`

### Linter + Rulesets
- **Linter tool**: `go vet` and `staticcheck`
- **Ruleset/config**: Default Go vet checks, staticcheck defaults
- **Custom rules**: None

### Naming/Conventions
- **File naming**: Standard Go conventions (`snake_case.go`)
- **Component structure**: Internal packages in `internal/`, migrations in `migrations/`
- **Variable conventions**: Go standard (camelCase for unexported, PascalCase for exported)
- **Project-specific patterns**:
  - SAML config in `internal/conf/saml.go`
  - CLI commands in `cmd/` directory
  - Build outputs to `./auth` binary

## Testing
### Frameworks
- **Unit test framework**: Go `testing` package
- **Integration test tools**: `.claude/scripts/container/test.sh` (runs in Docker)
- **E2E test framework**: TBD (inherited from upstream Supabase Auth)

### Coverage Targets
- **Line coverage target**: TBD (follow upstream standards)
- **Branch coverage target**: TBD
- **Required coverage areas**: Auth token validation, SAML flows, migration logic
- **Excluded from coverage**: Generated code, vendored deps

### Integration/E2E Scope
- **Test environment setup**: Docker Compose with PostgreSQL 15
- **Critical user paths**:
  - User signup/login flows
  - OAuth/SAML authentication
  - MFA/WebAuthn flows
  - Session management
- **Performance benchmarks**: TBD

## CI/CD
### Required PR Checks
- **Lint/format check**: `go fmt`, `go vet`, `staticcheck` (via `build.sh`)
- **Type check**: N/A (Go is statically typed; checked at compile time)
- **Unit tests**: `go test ./...`
- **Integration tests**: `.claude/scripts/container/test.sh`
- **Build verification**: `.claude/scripts/local/build.sh` must succeed
- **Security scan**: TBD (should scan for secrets, vulnerabilities)
- **Custom checks**: Verify `./auth version` works after build

### Branch Protection Rules
- **Protected branches**: `master` (main branch per git status)
- **Review requirements**: TBD (recommend at least 1 reviewer)
- **Status checks**: All PR checks must pass
- **Merge restrictions**: No force push to `master`

### Deployment Strategy
- **Environments**: Native (localhost DB, port 9999), Docker (containerized DB, port 9999), production TBD
- **Deploy process**:
  1. Build via `.claude/scripts/local/build.sh` or `.claude/scripts/container/build.sh`
  2. Run migrations: `./auth migrate -c .env`
  3. Start server: `./auth serve -c .env`
- **Rollback procedure**: Database migrations are idempotent; binary rollback via Git tags
- **Feature flags**: TBD (check upstream Supabase Auth)

## Dependencies
### Allowed/Blocked Dependencies
- **Approved list**: Follow upstream Supabase Auth dependencies
- **Blocked packages**: None explicitly blocked
- **Review process**: Ask before adding new deps (per Critical Behavior)
- **Version pinning strategy**: Go modules with `go.mod` and `go.sum`

## Security/Compliance
### Secrets Handling
- **Secret management tool**: Environment variables via `.env` (gitignored)
- **Environment variables**: 85+ variables in `.env`; `.env.docker` for Docker overrides
- **Rotation policy**: TBD (production secrets should be rotated regularly)

### License Policy
- **Allowed licenses**: Apache 2.0, MIT (check upstream Supabase Auth)
- **Prohibited licenses**: GPL variants (unless explicitly approved)
- **Attribution requirements**: Preserve upstream Supabase Auth attribution

### Special Checks
- **SAST tool**: TBD (recommend `gosec` or similar)
- **DAST tool**: TBD
- **SBOM generation**: TBD (Go modules provide dependency graph)
- **Compliance scans**: TBD

## Domain Gates
### Accessibility
- N/A (API service, no UI)

### Internationalization
- **Supported locales**: TBD (check upstream Supabase Auth email templates)
- **Translation process**: TBD
- **RTL support**: N/A (API service)

### Performance Budgets
- **Load time targets**: API response < 100ms for auth checks
- **Bundle size limits**: Binary size < 50MB (statically linked)
- **API response times**:
  - Token validation: < 50ms
  - User signup: < 500ms
  - OAuth flows: < 1s
- **Core Web Vitals**: N/A (API service)

## Overrides to Org Spec
List any deviations from the organizational claude.md with rationale.

### Override 1: Upstream Merge Restriction
- **What**: Do not merge upstream Supabase Auth changes without explicit review and approval
- **Why**: Fork has diverged with custom build scripts and SAML configuration; blind merge could break working setup
- **Risk mitigation**:
  - Document all divergences in this file
  - Goal: Return to mainline as soon as possible
  - Review all upstream changes file-by-file before merging

## Project-Specific Instructions

### Quick Start

#### Build and Run (Native Mode)

Both modes use port 9999. The difference is database connection:
- Native: connects to localhost:5432 (local PostgreSQL)
- Docker: connects to postgres:5432 (containerized PostgreSQL)

```bash
./.claude/scripts/local/build.sh  # Format, vet, lint, build
./auth migrate -c .env            # Run database migrations
./auth serve -c .env              # Start server on port 9999
```

#### Docker Mode

```bash
./.claude/scripts/container/build.sh  # First time: builds, runs migrations, stops
./.claude/scripts/container/dev.sh    # Start containers
./.claude/scripts/container/down.sh   # Stop containers
```

### Configuration

- `.env` - Complete working configuration (85+ variables) - **NEVER COMMIT**
- `.env.docker` - Docker-specific overrides ONLY (DATABASE_URL, paths) - **NEVER COMMIT**
- `example.env` - Template with comments (safe to commit)

Docker sources `.env` first, then applies `.env.docker` overrides.

### Database

Auth service runs on **port 9999** in both modes. Database connection differs:

**Native Mode:**
- Auth service: `localhost:9999`
- Database: `localhost:5432` (local PostgreSQL)
- User: `supabase_auth_admin` / Password: `root`
- Connect: `PGPASSWORD=root psql -h localhost -U supabase_auth_admin -d postgres`

**Docker Mode:**
- Auth service: `localhost:9999` (mapped from container)
- Database (external): `localhost:54321` (mapped from container)
- Database (internal): `postgres:5432` (Docker network)
- User: `supabase_auth_admin` / Password: `root`
- Connect: `PGPASSWORD=root psql -h localhost -p 54321 -U supabase_auth_admin -d postgres`

### Migrations

61 migrations covering:
- Initial schema (users, identities, sessions)
- OAuth/SAML support
- MFA/WebAuthn
- Latest: Sept 2025

Migrations are **idempotent** - safe to re-run. Always run migrations before starting the server.

### Scripts Overview

#### Local Development (`.claude/scripts/local/`)
- `build.sh` - Format + vet + staticcheck + build + verify

#### Container Operations (`.claude/scripts/container/`)
- `build.sh` - Full rebuild: build images, run migrations, stop
- `dev.sh` - Start containers with hot-reload
- `down.sh` - Stop containers
- `test.sh` - Run tests in containers
- `clean.sh` - Remove containers and volumes

### Key Entry Points
- **Main application**: `cmd/auth/main.go` (inferred from Supabase Auth structure)
- **API endpoints**: `internal/api/` (RESTful auth endpoints)
- **Background jobs**: TBD (check upstream for webhook/cleanup jobs)
- **CLI tools**: `./auth` binary with subcommands:
  - `./auth migrate [-c .env]` - Run migrations
  - `./auth serve [-c .env]` - Start server
  - `./auth version` - Show version
  - `./auth admin createuser [flags]` - Create admin user

### Critical Business Logic
- **Core domains**: User authentication, session management, OAuth/SAML flows, MFA
- **Key algorithms**: JWT token generation/validation, password hashing (bcrypt), SAML assertion parsing
- **Data flows**:
  1. User signup → create user record → send confirmation email
  2. Login → validate credentials → create session → return JWT
  3. OAuth → redirect to provider → callback → create/link user → create session
  4. SAML → SP-initiated flow → parse assertion → create/link user → create session
- **Integration points**:
  - Email service (SMTP)
  - OAuth providers (Google, GitHub, etc.)
  - SAML IDPs (enterprise SSO)
  - Database (PostgreSQL)

### SAML Configuration (Active)
- **Identity Provider**: Zitadel at `https://auth.aldervall.se`
- **Service Provider**: Supabase Auth at `https://auth.skogai.se`
- **Private Key**: Stored in `/home/skogix/supabase-saml-keys/private_key.base64`
- **Certificate**: Self-signed, 10-year validity
- **Endpoints**:
  - Metadata: `https://auth.skogai.se/sso/saml/metadata`
  - ACS URL: `https://auth.skogai.se/sso/saml/acs`
  - SLO URL: `https://auth.skogai.se/sso/saml/slo`
- **Zitadel Endpoints**:
  - SSO: `https://auth.aldervall.se/saml/v2/SSO`
  - SLO: `https://auth.aldervall.se/saml/v2/SLO`
  - Certificate: `https://auth.aldervall.se/saml/v2/certificate`
- **Status**: Service running locally on port 9999, metadata endpoint active
- **Database**: ✅ Zitadel provider registered (resource_id: `zitadel-aldervall`, domain: `aldervall.se`)
- **Next Steps**: Configure Zitadel SAML application with Service Provider metadata

### Known Issues/Tech Debt
- **Zitadel SAML App Configuration**: Need to configure Zitadel side with SP metadata from http://localhost:9999/sso/saml/metadata
- **Performance bottlenecks**: TBD (monitor JWT validation under load)
- **Security considerations**:
  - All JWT secrets must be in `.env`, never hardcoded
  - Database passwords must be rotated regularly
  - SAML assertions must be validated for signature and timestamp
  - Rate limiting on auth endpoints (check upstream implementation)
  - SAML private key stored in `/home/skogix/supabase-saml-keys/` with restricted permissions

---

**Note**: This is a fork of Supabase Auth. Do not merge upstream changes without careful review - we've diverged from mainline and want to get back as soon as possible. All custom changes should be documented here and in commit messages.
