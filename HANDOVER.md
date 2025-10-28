# Handover Notes - Script Cleanup Session

## What Was Done

### Created Script Structure
Replaced Makefile with organized shell scripts:

```
.claude/scripts/
├── local/          # Native development (port 9998)
│   ├── build.sh    # Build binary with version injection
│   ├── test.sh     # Run tests with coverage
│   ├── sec.sh      # Security checks (gosec)
│   ├── static.sh   # Static analysis (staticcheck + exhaustive)
│   ├── unused.sh   # Find unused code
│   ├── generate.sh # Code generation (oapi-codegen)
│   ├── format.sh   # Format code (gofmt)
│   ├── all.sh      # Run all checks + build
│   └── serve.sh    # Start auth service
└── container/      # Docker operations (port 9999)
    ├── dev.sh      # Start containers
    ├── down.sh     # Stop containers
    ├── build.sh    # Rebuild with migrations
    ├── test.sh     # Run tests in containers
    └── clean.sh    # Remove containers/volumes
```

### Script Design Principles
- All scripts assume execution from project root (`/home/skogix/dev/auth`)
- No path gymnastics with `cd "$(dirname "$0")/../.."`
- Minimal output (no fluff echo statements)
- Use `set -euo pipefail` for safety

### Removed Scripts (Redundant)
- `deps.sh` - Already done in build.sh
- `migrate.sh` - Just use `./auth migrate` directly
- `vet.sh` - Now part of build.sh

### Updated build.sh
```bash
#!/usr/bin/env bash
set -euo pipefail

go mod download
go mod verify
go vet ./...

VERSION="skogai-0.0.1"
go build -ldflags "-X github.com/supabase/auth/internal/utilities.Version=$VERSION"
./auth version
```

**Changes from original Makefile:**
- Hardcoded version (no git describe magic)
- Removed CGO_ENABLED=0 (uses Go defaults)
- Removed -buildvcs=false (uses Go defaults)
- Removed ARM64 cross-compile (only builds for local machine)
- Added verification step (`./auth version`)
- Integrated `go vet` into build

### Slash Commands
Created two slash commands:
- `/local` - Runs local development scripts
- `/container` - Runs container scripts

## Documentation Updates

### Added to CLAUDE.md
Full auth CLI documentation:
- Core commands (migrate, serve, version, admin)
- Global flags (`-c` for config, `-d` for config directory)
- Usage examples

## Known Issues

### SAML Tests Failing
Tests in `internal/conf/saml_test.go` crash with nil pointer:
```
--- FAIL: TestSAMLConfiguration/PopulateFieldInvalidCreateCertificate
panic: runtime error: invalid memory address or nil pointer dereference
```

**Root cause:** Test creates SAMLConfiguration with invalid key but never calls `PopulateFields()`, so `RSAPrivateKey` stays nil. Then `createCertificate()` tries to use nil key → crash.

**Status:** Known issue, not fixed. Tests were added for coverage but are broken.

### Email Validation Test Failing
```
--- FAIL: TestValidateEmailExtended
Error: An error is expected but got nil.
```

One test case expects rejection but email passes validation.

**Status:** Known issue, not fixed.

## Project Structure

### Development Modes
1. **Native Mode** (port 9998)
   - Uses local PostgreSQL at `localhost:5432`
   - Run: `./auth serve`

2. **Container Mode** (port 9999)
   - Uses containerized PostgreSQL at `localhost:54321`
   - Run: `./.claude/scripts/container/dev.sh`

### Database
- User: `supabase_auth_admin`
- Password: `root`
- Native: `localhost:5432`
- Container: `localhost:54321`

### Configuration
- `.env` - Complete working configuration
- `.env.docker` - Docker-specific overrides only
- `hack/test.env` - Test configuration

### Auth CLI Commands
- `./auth migrate [-c .env]` - Run migrations
- `./auth serve [-c .env]` - Start server
- `./auth version` - Show version
- `./auth admin createuser` - Create admin user

## Open Questions

1. **test.sh** - Should it be simplified to just `go test ./...` or keep all the flags?
2. **SAML certs** - Located in `certs/` but not configured in `.env`
3. **Container tests** - Still reference Makefile commands internally

## Next Steps (Not Done)

- [ ] Review remaining local scripts (sec.sh, static.sh, unused.sh, etc.)
- [ ] Review container scripts for correctness
- [ ] Decide on test.sh complexity
- [ ] Update slash commands to reference final script list
- [ ] Test all scripts work correctly
- [ ] Update all.sh to call correct scripts

## Commands to Remember

### Build and run
```bash
./.claude/scripts/local/build.sh
./auth serve
```

### Run tests
```bash
go test ./...  # Basic
./.claude/scripts/local/test.sh  # Full with coverage
```

### Docker
```bash
./.claude/scripts/container/build.sh  # First time
./.claude/scripts/container/dev.sh    # Start
./.claude/scripts/container/down.sh   # Stop
```
