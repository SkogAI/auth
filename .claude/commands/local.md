# Local Development Operations

Run local development tasks for the Supabase Auth service (Native Mode - port 9998).

## Available Operations

- **build** - Build the auth binary (and arm64 variant)
- **deps** - Install and verify Go dependencies
- **migrate** - Run database migrations
- **test** - Run tests with coverage
- **vet** - Run go vet code analysis
- **sec** - Check for security vulnerabilities with gosec
- **static** - Run static analysis (staticcheck + exhaustive)
- **unused** - Find unused code
- **generate** - Generate code from specs
- **format** - Format code with gofmt
- **all** - Run vet, sec, static, and build
- **serve** - Start the auth service locally

## Task

1. Ask the user which operation to run (if not specified in the request)
2. Execute the corresponding script: `.claude/scripts/local/{operation}.sh`
3. Report the results

## Examples

User: "build the project"
→ Run `.claude/scripts/local/build.sh`

User: "run tests"
→ Run `.claude/scripts/local/test.sh`

User: "run all checks"
→ Run `.claude/scripts/local/all.sh`

## Scripts Location

All scripts are in `.claude/scripts/local/`:
- `build.sh` - Build binaries with version info
- `deps.sh` - Install dependencies
- `migrate.sh` - Run migrations (calls `./hack/migrate.sh postgres`)
- `test.sh` - Run tests with coverage
- `vet.sh` - Go vet analysis
- `sec.sh` - Security checks (gosec)
- `static.sh` - Static analysis (staticcheck + exhaustive)
- `unused.sh` - Find unused code
- `generate.sh` - Generate code (oapi-codegen)
- `format.sh` - Format code (gofmt)
- `all.sh` - Run vet, sec, static, and build
- `serve.sh` - Start auth service

## Context

- Port: 9998
- Database: `localhost:5432`
- User: `supabase_auth_admin:root`

You can also run scripts directly: `./.claude/scripts/local/build.sh`
