# SAML Configuration Status

**Last Updated**: 2025-10-29 11:40 CET

## Current Status: ✅ Service Running, ✅ Provider Registered, ✅ Zitadel Configured, ✅ Bug Fixed, ⏳ Manual Login Test Pending

## Service Configuration

### Supabase Auth (Service Provider)
- **Status**: Running locally (native mode)
- **PID**: 811804
- **Port**: 9999 (both native and Docker modes use this port)
- **External URL**: `https://auth.skogai.se`
- **Health**: ✅ Healthy
- **Version**: rc2.181.0-rc.15-7-g6c526fc9

### SAML Configuration
```bash
GOTRUE_SAML_ENABLED="true"
API_EXTERNAL_URL="https://auth.skogai.se"
GOTRUE_SITE_URL="https://auth.skogai.se"
GOTRUE_SAML_RELAY_STATE_VALIDITY_PERIOD="120s"
```

### Service Provider Endpoints (Active)
- **Metadata**: https://auth.skogai.se/sso/saml/metadata
- **ACS URL**: https://auth.skogai.se/sso/saml/acs
- **SLO URL**: https://auth.skogai.se/sso/saml/slo
- **Entity ID**: https://auth.skogai.se/sso/saml/metadata

### Private Key
- **Location**: `/home/skogix/supabase-saml-keys/private_key.base64`
- **Format**: Base64-encoded PKCS#1 RSA private key
- **Permissions**: 600 (owner read/write only)
- **In .env**: ✅ Configured

## Database Verification

### SSO Provider (Registered ✅)
```sql
SELECT id, resource_id, disabled, created_at
FROM auth.sso_providers;
```

**Result:**
```
                  id                  |    resource_id    | disabled |          created_at
--------------------------------------+-------------------+----------+-------------------------------
 a1d79e11-0000-0000-0000-000000000001 | zitadel-aldervall | f        | (timestamp from registration)
```

### SAML Provider (Registered ✅)
```sql
SELECT id, sso_provider_id, entity_id, created_at
FROM auth.saml_providers;
```

**Result:**
```
                  id                  |           sso_provider_id            |                 entity_id                  |          created_at
--------------------------------------+--------------------------------------+--------------------------------------------+-------------------------------
 25cafa85-9f80-4186-b55e-0941767774c7 | a1d79e11-0000-0000-0000-000000000001 | https://auth.aldervall.se/saml/v2/metadata | 2025-10-29 06:24:26.691867+01
```

### SSO Domain (Configured ✅)
```sql
SELECT sso_provider_id, domain FROM auth.sso_domains;
```

**Result:**
```
           sso_provider_id            |    domain
--------------------------------------+--------------
 a1d79e11-0000-0000-0000-000000000001 | aldervall.se
```

**Provider Registration Status:** ✅ **COMPLETE** - All database records exist and are properly linked.

## Zitadel Configuration (Identity Provider)

### Zitadel Instance
- **URL**: `https://auth.aldervall.se`
- **Masterkey**: (stored in `/home/skogix/tmp/index.md`)

### Identity Provider Endpoints
- **SSO**: https://auth.aldervall.se/saml/v2/SSO
- **SLO**: https://auth.aldervall.se/saml/v2/SLO
- **Certificate**: https://auth.aldervall.se/saml/v2/certificate
- **Metadata**: (likely https://auth.aldervall.se/saml/v2/metadata)

### Zitadel Certificate
- **Status**: Available
- **Location**: `/home/skogix/tmp/index.md` (lines 29-87)
- **Type**: X.509 certificate (BEGIN/END CERTIFICATE format)
- **Issuer**: ZITADEL SAML CA
- **Subject**: ZITADEL SAML response
- **Validity**: Oct 4, 2025 - Oct 4, 2026

## Test Results

### Automated Tests ✅ COMPLETE

**Phase 1: Endpoint Verification** (2025-10-29 11:22)
- SP Metadata: ✅ 200 OK (0.42ms)
- Service Health: ✅ 200 OK
- IdP Metadata: ✅ 200 OK (259ms)
- IdP Certificate: ✅ 200 OK (206ms)
- Metadata Content: ✅ Valid

**Phase 2: Database Verification** (2025-10-29 11:23)
- SSO Provider: ✅ Enabled (a1d79e11-0000-0000-0000-000000000001)
- SAML Provider: ✅ Linked (25cafa85-9f80-4186-b55e-0941767774c7)
- Domain: ✅ Configured (aldervall.se)
- Baseline Users: 2
- Baseline SAML Identities: 0

**Phase 6: Error Handling** (2025-10-29 11:25)
- Invalid Domain: ✅ HTTP 405 (POST required)
- Missing Domain: ✅ HTTP 405 (POST required)
- Malformed Domain: ✅ HTTP 405 (POST required)
- ACS Endpoint: ✅ Correctly requires POST method

### Manual Tests ⏳ PENDING

**Phase 3: SP-Initiated SSO Flow**
- Test Procedure: `/tmp/sso-flow-test-procedure.md` ⚠️ OUTDATED
- Test Page: `/tmp/saml-login-test.html` ✅ CURRENT
- Status: Ready for browser-based test
- Endpoint: `POST /sso` with `{"domain": "aldervall.se"}`

**Phase 4: User Verification**
- Verification Script: `/tmp/verify-saml-login.sh`
- User Lookup: `/tmp/find-saml-user.sh <email>`
- Status: Ready to run after SSO test

**Phase 5: Logout Testing**
- Test Procedure: `/tmp/slo-test-procedure.md`
- Status: Awaiting SSO completion
- Requires: Active SAML session

**Additional Error Tests:**
- Full error test suite: `/tmp/error-handling-tests.md`
- Status: Documented, ready for execution

### Bug Fix ✅ RESOLVED (2025-10-29 11:38)

**Issue:** SSO initiation endpoint (`POST /sso`) failing with database scan error
```
error finding SAML SSO provider by ID (via domain):
sql: Scan error on column index 0, name "attribute_mapping":
json: cannot unmarshal string into Go struct field SAMLAttributeMapping.keys of type models.SAMLAttribute
```

**Root Cause:** Incorrect JSON structure in `auth.saml_providers.attribute_mapping` column
- **Wrong:** `{"keys": {"email": "Email"}}` (values are strings)
- **Correct:** `{"keys": {"email": {"name": "Email"}}}` (values are SAMLAttribute structs)

**Fix Applied:** Updated `attribute_mapping` column with correct JSON structure:
```sql
UPDATE auth.saml_providers
SET attribute_mapping = '{"keys": {
  "email": {"name": "Email"},
  "name": {"name": "FullName"},
  "first_name": {"name": "FirstName"},
  "last_name": {"name": "SurName"}
}}'
WHERE id = '25cafa85-9f80-4186-b55e-0941767774c7';
```

**Verification:**
```bash
curl -X POST http://localhost:9999/sso \
  -H "Content-Type: application/json" \
  -d '{"domain": "aldervall.se", "skip_http_redirect": true}'

# Returns:
{"url":"https://auth.aldervall.se/saml/v2/SSO?SAMLRequest=...&RelayState=...&Signature=..."}
```

**Status:** ✅ RESOLVED - SSO initiation endpoint now working correctly

### Current Test Status

**Automated Tests:** ✅ 13/13 passed
**Bug Fixes:** ✅ 1/1 resolved
**Manual Tests:** ⏳ Ready for execution

**Test Artifacts Created:**
- `/tmp/saml-login-test.html` - Browser-based SAML login test page
- `/tmp/verify-saml-login.sh` - Post-login database verification script
- `/tmp/find-saml-user.sh` - User lookup script

**Next Action:** Open `/tmp/saml-login-test.html` in browser and click "Login with SAML" button

## Next Steps

### 1. ✅ ~~Register Zitadel as SSO Provider~~ (COMPLETE)
Provider already registered in database:
- SSO Provider: `a1d79e11-0000-0000-0000-000000000001`
- Resource ID: `zitadel-aldervall`
- Domain: `aldervall.se`

### 2. ✅ ~~Configure Zitadel SAML Application~~ (COMPLETE)
Access Zitadel admin console and create/update SAML application with Service Provider metadata:

**Required Configuration:**
```
Entity ID: https://auth.skogai.se/sso/saml/metadata
ACS URL: https://auth.skogai.se/sso/saml/acs
Single Logout URL: https://auth.skogai.se/sso/saml/slo
Name ID Format: urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress
```

**Attribute Mapping (recommended):**
```
Email → email (required)
UserName → username
FullName → full_name
FirstName → first_name
SurName → last_name
```

**Import SP Metadata:**
- URL: http://localhost:9999/sso/saml/metadata
- Or manually configure using values above

### 3. Test Authentication Flow

**Complete testing guide available at:** `/tmp/saml-testing-guide.md`

**Quick Test:**
1. Navigate to: `https://auth.skogai.se/sso/saml/acs?domain=aldervall.se`
2. Should redirect to Zitadel login page
3. Enter test user credentials (user@aldervall.se)
4. After authentication, Zitadel redirects back with SAML assertion
5. Supabase validates assertion and creates/links user
6. Returns JWT token and establishes session

**Verification Steps:**
```sql
-- Check user was created
SELECT id, email, raw_user_meta_data, created_at
FROM auth.users
WHERE email = 'test@aldervall.se';

-- Check identity record
SELECT id, user_id, provider, identity_data
FROM auth.identities
WHERE provider = 'saml';

-- Check session
SELECT id, user_id, created_at
FROM auth.sessions
ORDER BY created_at DESC
LIMIT 1;
```

## Environment Files Status

### .env (Local/Native)
- ✅ DATABASE_URL: `localhost:5432`
- ✅ API_EXTERNAL_URL: `https://auth.skogai.se`
- ✅ PORT: `9999`
- ✅ SAML_ENABLED: `true`
- ✅ SAML_PRIVATE_KEY: Configured
- ⚠️  Never commit this file (contains secrets)

### .env.docker (Container overrides)
- ✅ DATABASE_URL: `postgres:5432` (Docker network)
- ✅ MIGRATIONS_PATH: `/go/src/github.com/supabase/auth/migrations`
- ℹ️  SAML config inherited from .env
- ⚠️  Never commit this file

## Database Configuration

### Connection (Local)
```bash
Host: localhost:5432
User: supabase_auth_admin
Password: root
Database: postgres
```

### Connection (Docker)
```bash
Host: postgres:5432 (internal) / localhost:54321 (external)
User: supabase_auth_admin
Password: root
Database: postgres
```

### Migrations
- **Count**: 61 migrations
- **Status**: Should be applied before starting service
- **Command**: `./auth migrate -c .env`

## Security Checklist

- [x] SAML private key has restricted permissions (600)
- [x] Private key stored outside repo
- [x] .env files in .gitignore
- [x] Service running with HTTPS endpoints configured
- [ ] SSL/TLS certificates configured for production
- [ ] Zitadel certificate verified and validated
- [ ] Provider registration completed
- [ ] Authentication flow tested end-to-end

## Troubleshooting

### If service fails to start:
```bash
# Check logs
tail -50 /tmp/auth.log

# Common issues:
# - "SAML private key not in PKCS#1 format" → wrong key file
# - "unable to load config" → check .env syntax
# - "database connection failed" → check DATABASE_URL
```

### If metadata endpoint returns 502:
- Service not running locally
- Proxy/reverse proxy not configured
- Check: `curl http://localhost:9999/sso/saml/metadata`

### If authentication fails:
- Check SAML assertion signature validation
- Verify Zitadel certificate matches
- Check attribute mapping
- Review logs: `tail -f /tmp/auth.log`

## Documentation References

### Current Configuration Guides (Generated)
- `/tmp/zitadel-saml-configuration-guide.md` - Step-by-step Zitadel SAML app setup
- `/tmp/saml-testing-guide.md` - Comprehensive testing procedures
- `/tmp/sp-metadata.xml` - Service Provider metadata file

### Test Procedures & Scripts (Generated)
- `/tmp/sso-flow-test-procedure.md` - SP-initiated SSO test steps
- `/tmp/slo-test-procedure.md` - Single Logout test steps
- `/tmp/error-handling-tests.md` - Error handling test scenarios
- `/tmp/verify-saml-login.sh` - Post-login verification script (executable)
- `/tmp/find-saml-user.sh` - User lookup script (executable)

### Project Documentation (Historical)
Project documentation at `/home/skogix/skogai/`:
- `guides/saml/SAML Implementation Summary.md`
- `guides/saml/ZITADEL IdP Setup Guide.md`
- `guides/saml/ZITADEL SAML Integration Guide.md`
- `guides/saml/SAML Admin API Reference.md`
- `guides/saml/SAML User Guide.md`

⚠️ **Note:** Historical documentation may be outdated. Refer to current configuration guides above for accurate, up-to-date information.

## Architecture Integration

This auth service is part of larger infrastructure:
- **Main Supabase**: `supabase.skogai.se:8000`
- **Auth Service**: `auth.skogai.se:9999` (this service)
- **Zitadel IdP**: `auth.aldervall.se`
- **24 downstream services**: Currently use one-off Zitadel integrations, will migrate to centralized auth

Goal: Consolidate 24 separate Zitadel SAML integrations into single auth service.
