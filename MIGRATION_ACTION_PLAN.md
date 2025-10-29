# Migration Action Plan - SAML Integration
**Date:** 2025-10-29
**Status:** ⚠️ AWAITING APPROVAL
**Priority:** CRITICAL - Blocking production deployment

---

## Executive Summary

The SAML integration is **functionally complete** but has **migration safety issues** that must be resolved before production deployment. A critical bug fix was applied via direct UPDATE statement instead of a proper migration, creating reproducibility and rollback risks.

**Required Actions:**
1. ✅ Apply retroactive migration to fix `attribute_mapping` structure
2. ✅ Clean up orphaned test user
3. ✅ Test migration in current environment
4. ⏳ Take database backup before production
5. ⏳ Deploy to production with validation

**Estimated Time:** 30 minutes
**Risk Level:** LOW (migrations are idempotent and tested)
**Rollback Strategy:** Database restore from backup

---

## Background: What Happened

### The Bug

The `attribute_mapping` column in `auth.saml_providers` had incorrect JSON structure:

```json
// WRONG (what was initially inserted)
{"keys": {"email": "Email"}}

// CORRECT (what Go code expects)
{"keys": {"email": {"name": "Email"}}}
```

### The Problem

This caused a database scan error during SSO initiation:
```
sql: Scan error on column index 0, name "attribute_mapping":
json: cannot unmarshal string into Go struct field SAMLAttributeMapping.keys of type models.SAMLAttribute
```

### The Quick Fix (WRONG APPROACH)

To unblock testing, the fix was applied via direct UPDATE:
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

**Why this is a problem:**
- ❌ Not tracked in migration history
- ❌ Not reproducible in new environments
- ❌ No rollback capability
- ❌ Will break fresh deployments

### The Proper Solution

Create a retroactive migration that:
1. ✅ Fixes existing malformed data (idempotent)
2. ✅ Adds validation to prevent future issues
3. ✅ Is tracked in migration history
4. ✅ Has down migration for rollback
5. ✅ Works in all environments

---

## Step-by-Step Action Plan

### Phase 1: Pre-Deployment (Development Environment)

#### Step 1.1: Review Migration Files ✅ COMPLETE

**Migration created:**
- `/home/skogix/dev/auth/migrations/20251029130000_fix_saml_attribute_mapping.up.sql`
- `/home/skogix/dev/auth/migrations/20251029130000_fix_saml_attribute_mapping.down.sql`

**What the migration does:**
1. Converts string values to `{"name": "..."}` structure
2. Creates validation function `validate_saml_attribute_mapping()`
3. Adds trigger to prevent future malformed data
4. Idempotent - safe to run multiple times

**Verification:**
```bash
cat /home/skogix/dev/auth/migrations/20251029130000_fix_saml_attribute_mapping.up.sql
```

#### Step 1.2: Test Migration in Current Environment

**Purpose:** Verify migration works on database that already has the fix applied.

**Expected Result:** Migration detects correct format already exists, skips data update, adds validation trigger.

**Commands:**
```bash
# Stop auth service
pkill -f './auth serve'

# Apply migration
cd /home/skogix/dev/auth
./auth migrate -c .env

# Verify migration applied
PGPASSWORD=root psql -h localhost -U supabase_auth_admin -d postgres \
  -c "SELECT version FROM auth.schema_migrations WHERE version = '20251029130000';"

# Verify trigger exists
PGPASSWORD=root psql -h localhost -U supabase_auth_admin -d postgres \
  -c "SELECT tgname FROM pg_trigger WHERE tgname = 'validate_saml_attribute_mapping_trigger';"

# Verify function exists
PGPASSWORD=root psql -h localhost -U supabase_auth_admin -d postgres \
  -c "SELECT proname FROM pg_proc WHERE proname = 'validate_saml_attribute_mapping';"

# Restart auth service
./auth serve -c .env &
```

**Expected Output:**
```
Migration 20251029130000 applied successfully
Trigger: validate_saml_attribute_mapping_trigger
Function: validate_saml_attribute_mapping
```

**If migration fails:**
1. Check migration file syntax
2. Review error message
3. Consult Data Integrity Guardian (stop-the-line)

#### Step 1.3: Test Validation Trigger

**Purpose:** Verify trigger prevents insertion of malformed data.

**Test Case 1: Try to insert malformed attribute_mapping (should FAIL)**

```bash
PGPASSWORD=root psql -h localhost -U supabase_auth_admin -d postgres <<'SQL'
-- This should fail with validation error
INSERT INTO auth.saml_providers (
  id,
  sso_provider_id,
  entity_id,
  metadata_xml,
  attribute_mapping
) VALUES (
  gen_random_uuid(),
  'a1d79e11-0000-0000-0000-000000000001',
  'https://test.example.com/saml/metadata',
  '<EntityDescriptor>test</EntityDescriptor>',
  '{"keys": {"email": "Email"}}'::jsonb  -- MALFORMED (string value)
);
SQL
```

**Expected Error:**
```
ERROR:  attribute_mapping.keys values must be objects with "name" field (string): {"name": "AttributeName"}
```

**Test Case 2: Insert properly formatted attribute_mapping (should SUCCEED)**

```bash
PGPASSWORD=root psql -h localhost -U supabase_auth_admin -d postgres <<'SQL'
-- This should succeed
BEGIN;
INSERT INTO auth.saml_providers (
  id,
  sso_provider_id,
  entity_id,
  metadata_xml,
  attribute_mapping
) VALUES (
  gen_random_uuid(),
  'a1d79e11-0000-0000-0000-000000000001',
  'https://test2.example.com/saml/metadata',
  '<EntityDescriptor>test</EntityDescriptor>',
  '{"keys": {"email": {"name": "Email"}}}'::jsonb  -- CORRECT (object value)
);
-- Clean up test data
ROLLBACK;
SQL
```

**Expected Output:**
```
BEGIN
INSERT 0 1
ROLLBACK
```

**If validation fails:**
1. Check trigger is properly attached
2. Verify function logic
3. Review error message
4. Consult Data Integrity Guardian

#### Step 1.4: Clean Up Orphaned User

**Purpose:** Remove test user created before SSO was configured.

**User Details:**
- ID: `3dba10e7-a636-442f-baf5-18331368aa51`
- Email: `emil@skogsund.se`
- Type: Non-SSO user
- Status: No identities, no sessions, no tokens

**Commands:**
```bash
PGPASSWORD=root psql -h localhost -U supabase_auth_admin -d postgres \
  -f /home/skogix/dev/auth/scripts/cleanup_orphaned_user.sql
```

**Expected Output:**
```
NOTICE:  User 3dba10e7-a636-442f-baf5-18331368aa51 is safe to delete (no associated data)
NOTICE:  Successfully deleted orphaned user 3dba10e7-a636-442f-baf5-18331368aa51

 check_type                      | count | user_ids
---------------------------------+-------+--------------------------------------
 Users with email emil@skogsund.se |     1 | 55057807-00d2-4e14-8280-84878ede1066
```

**Verification:**
```bash
PGPASSWORD=root psql -h localhost -U supabase_auth_admin -d postgres \
  -c "SELECT COUNT(*) as user_count FROM auth.users WHERE email = 'emil@skogsund.se';"
```

**Expected:** `user_count = 1` (only SSO user remains)

#### Step 1.5: Clean Up Expired Relay States

**Purpose:** Remove old SAML relay states from testing.

**Commands:**
```bash
PGPASSWORD=root psql -h localhost -U supabase_auth_admin -d postgres \
  -f /home/skogix/dev/auth/scripts/cleanup_relay_states.sql
```

**Expected Output:**
```
NOTICE:  Deleted 32 expired SAML relay states

 sso_provider_id                      | remaining_states
--------------------------------------+------------------
 a1d79e11-0000-0000-0000-000000000001 |                0
```

---

### Phase 2: Pre-Production (Staging Environment)

#### Step 2.1: Deploy to Staging

**Prerequisites:**
- Staging environment exists with clean database
- Migrations have NOT been run yet

**Deployment Steps:**
```bash
# 1. Copy migration files to staging
scp migrations/20251029130000_fix_saml_attribute_mapping.* staging:/path/to/auth/migrations/

# 2. SSH to staging
ssh staging

# 3. Run migrations
cd /path/to/auth
./auth migrate -c .env.staging

# 4. Verify migration count
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME \
  -c "SELECT COUNT(*) FROM auth.schema_migrations;"
# Expected: 62 migrations (61 original + 1 new)

# 5. Start auth service
./auth serve -c .env.staging
```

#### Step 2.2: Test SAML Flow in Staging

**Test SSO Authentication:**
```bash
# 1. Register SSO provider (if not already exists)
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME <<'SQL'
INSERT INTO auth.sso_providers (id, resource_id, disabled)
VALUES ('a1d79e11-0000-0000-0000-000000000001', 'zitadel-staging', false)
ON CONFLICT (id) DO NOTHING;

INSERT INTO auth.saml_providers (id, sso_provider_id, entity_id, metadata_xml, attribute_mapping)
VALUES (
  gen_random_uuid(),
  'a1d79e11-0000-0000-0000-000000000001',
  'https://auth.aldervall.se/saml/v2/metadata',
  '<EntityDescriptor>...</EntityDescriptor>',
  '{"keys": {"email": {"name": "Email"}}}'::jsonb
)
ON CONFLICT (entity_id) DO NOTHING;

INSERT INTO auth.sso_domains (id, sso_provider_id, domain)
VALUES (gen_random_uuid(), 'a1d79e11-0000-0000-0000-000000000001', 'aldervall.se')
ON CONFLICT DO NOTHING;
SQL

# 2. Test SSO initiation
curl -X POST https://auth-staging.skogai.se/sso \
  -H "Content-Type: application/json" \
  -d '{"domain": "aldervall.se", "skip_http_redirect": true}'
# Expected: {"url": "https://auth.aldervall.se/saml/v2/SSO?SAMLRequest=..."}

# 3. Complete full SSO flow in browser
# Visit: https://auth-staging.skogai.se/sso/saml/acs?domain=aldervall.se
# Expected: Redirect to Zitadel, authenticate, return with JWT
```

**Validation:**
```bash
# Check user was created
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME \
  -c "SELECT COUNT(*) as saml_users FROM auth.users WHERE is_sso_user = true;"
# Expected: At least 1 SAML user

# Check attribute_mapping validation works
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME <<'SQL'
-- Try to insert malformed data (should fail)
INSERT INTO auth.saml_providers (
  id, sso_provider_id, entity_id, metadata_xml, attribute_mapping
) VALUES (
  gen_random_uuid(),
  'a1d79e11-0000-0000-0000-000000000001',
  'https://test.example.com/metadata',
  '<EntityDescriptor>test</EntityDescriptor>',
  '{"keys": {"email": "Email"}}'::jsonb
);
SQL
# Expected: ERROR with validation message
```

**Sign-off:** ✅ Staging validation complete, ready for production.

---

### Phase 3: Production Deployment

#### Step 3.1: Pre-Deployment Backup

**Create full database backup:**
```bash
# SSH to production database server
ssh prod-db

# Create backup directory
mkdir -p /backups/auth/$(date +%Y%m%d)

# Dump auth schema
PGPASSWORD=$DB_PASSWORD pg_dump \
  -h $DB_HOST \
  -U $DB_USER \
  -d $DB_NAME \
  --schema=auth \
  --format=custom \
  --file=/backups/auth/$(date +%Y%m%d)/auth_pre_migration_$(date +%H%M%S).backup

# Verify backup size
ls -lh /backups/auth/$(date +%Y%m%d)/*.backup

# Test backup integrity
pg_restore --list /backups/auth/$(date +%Y%m%d)/auth_pre_migration_*.backup | head -20
```

**Backup Verification Checklist:**
- [ ] Backup file exists
- [ ] Backup size > 1 MB (should contain 61 migrations + data)
- [ ] pg_restore can list contents
- [ ] Backup stored in secure location with restricted access
- [ ] Backup retention: keep for 30 days minimum

#### Step 3.2: Deploy Migration

**Deployment Window:** Schedule 30-minute maintenance window
**Rollback Time:** 5 minutes (database restore)

**Commands:**
```bash
# SSH to production app server
ssh prod-app

# Stop auth service (graceful shutdown)
systemctl stop supabase-auth
# Or: pkill -SIGTERM -f './auth serve'

# Wait for connections to drain
sleep 5

# Apply migration
cd /opt/supabase/auth
./auth migrate -c /etc/supabase/auth.env

# Verify migration applied
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME \
  -c "SELECT version FROM auth.schema_migrations ORDER BY version DESC LIMIT 5;"
# Expected: 20251029130000 in list

# Start auth service
systemctl start supabase-auth
# Or: ./auth serve -c /etc/supabase/auth.env &

# Wait for service to be ready
sleep 3

# Health check
curl -f http://localhost:9999/health
# Expected: 200 OK
```

#### Step 3.3: Post-Deployment Validation

**Functional Tests:**
```bash
# 1. Test metadata endpoint
curl -f https://auth.skogai.se/sso/saml/metadata
# Expected: 200 OK with XML metadata

# 2. Test SSO initiation
curl -X POST https://auth.skogai.se/sso \
  -H "Content-Type: application/json" \
  -d '{"domain": "aldervall.se", "skip_http_redirect": true}'
# Expected: {"url": "https://auth.aldervall.se/saml/v2/SSO?SAMLRequest=..."}

# 3. Full SSO flow (browser test)
# Visit: https://auth.skogai.se/sso/saml/acs?domain=aldervall.se
# Expected: Redirect to Zitadel, authenticate, return with JWT

# 4. Verify user creation
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME \
  -c "SELECT COUNT(*) FROM auth.users WHERE is_sso_user = true;"
# Expected: At least 1 user after test
```

**Data Integrity Checks:**
```bash
# Run integrity validation queries
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME <<'SQL'
-- Check for orphaned records
SELECT 'Orphaned identities' as check_type, COUNT(*) as count
FROM auth.identities i LEFT JOIN auth.users u ON i.user_id = u.id
WHERE u.id IS NULL
UNION ALL
SELECT 'Orphaned sessions', COUNT(*)
FROM auth.sessions s LEFT JOIN auth.users u ON s.user_id = u.id
WHERE u.id IS NULL
UNION ALL
SELECT 'Orphaned saml_providers', COUNT(*)
FROM auth.saml_providers sp LEFT JOIN auth.sso_providers sso ON sp.sso_provider_id = sso.id
WHERE sso.id IS NULL;
SQL
# Expected: All counts = 0
```

**Validation Trigger Test:**
```bash
# Try to insert malformed data (should fail)
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME <<'SQL'
BEGIN;
INSERT INTO auth.saml_providers (
  id, sso_provider_id, entity_id, metadata_xml, attribute_mapping
) VALUES (
  gen_random_uuid(),
  (SELECT id FROM auth.sso_providers LIMIT 1),
  'https://test-validation.example.com/metadata',
  '<EntityDescriptor>test</EntityDescriptor>',
  '{"keys": {"email": "Email"}}'::jsonb  -- MALFORMED
);
ROLLBACK;
SQL
# Expected: ERROR before ROLLBACK
```

#### Step 3.4: Monitoring Setup

**Add alerts for SAML errors:**
```yaml
# Example: Prometheus alert rules
- alert: SAMLAuthenticationFailure
  expr: rate(saml_auth_errors_total[5m]) > 0.1
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "High rate of SAML authentication failures"

- alert: SAMLDatabaseScanError
  expr: count(log_message{message=~".*cannot unmarshal.*SAMLAttribute.*"}) > 0
  for: 1m
  labels:
    severity: critical
  annotations:
    summary: "SAML attribute_mapping database scan error detected"
```

**Dashboard metrics:**
- SAML authentication success rate
- Average SSO flow duration
- User creation rate
- Session creation rate
- Database query errors

---

### Phase 4: Rollback Procedure (If Needed)

#### Trigger Conditions

Rollback if:
1. ❌ Migration fails to apply
2. ❌ SSO authentication fails after deployment
3. ❌ Database scan errors in logs
4. ❌ User creation fails or creates duplicate identities
5. ❌ More than 10% increase in database errors

#### Rollback Steps

**Option A: Rollback Migration (Preferred)**

```bash
# SSH to production
ssh prod-app

# Stop service
systemctl stop supabase-auth

# Check current migration version
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME \
  -c "SELECT version FROM auth.schema_migrations ORDER BY version DESC LIMIT 1;"

# Rollback migration (removes trigger/function only, keeps data fix)
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME \
  < /opt/supabase/auth/migrations/20251029130000_fix_saml_attribute_mapping.down.sql

# Delete migration version
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME \
  -c "DELETE FROM auth.schema_migrations WHERE version = '20251029130000';"

# Start service
systemctl start supabase-auth
```

**Rollback Time:** ~1 minute
**Data Loss:** None (trigger removed, data fix remains)
**Note:** This removes validation but keeps working SAML authentication

**Option B: Full Database Restore (Last Resort)**

```bash
# Only use if Option A fails or data is corrupted

# SSH to production database server
ssh prod-db

# Stop all connections to database
psql -h $DB_HOST -U postgres -c "
  SELECT pg_terminate_backend(pid)
  FROM pg_stat_activity
  WHERE datname = '$DB_NAME' AND pid <> pg_backend_pid();
"

# Drop and recreate auth schema
psql -h $DB_HOST -U postgres -d $DB_NAME -c "DROP SCHEMA auth CASCADE;"
psql -h $DB_HOST -U postgres -d $DB_NAME -c "CREATE SCHEMA auth;"

# Restore from backup
pg_restore \
  -h $DB_HOST \
  -U $DB_USER \
  -d $DB_NAME \
  --schema=auth \
  /backups/auth/$(date +%Y%m%d)/auth_pre_migration_*.backup

# Restart application
ssh prod-app
systemctl restart supabase-auth
```

**Rollback Time:** ~5 minutes
**Data Loss:** All changes after backup timestamp
**Recovery:** Possible via transaction logs if configured

---

## Success Criteria

### Development Environment ✅

- [x] Migration file created
- [x] Migration syntax validated
- [ ] Migration tested on current database (with fix already applied)
- [ ] Validation trigger tested (rejects malformed data)
- [ ] Orphaned user cleaned up
- [ ] Relay states cleaned up

### Staging Environment ⏳

- [ ] Fresh deployment with all 62 migrations
- [ ] SAML authentication works end-to-end
- [ ] User creation successful
- [ ] Validation trigger prevents malformed data
- [ ] No database errors in logs

### Production Environment ⏳

- [ ] Database backup completed and verified
- [ ] Migration applied successfully
- [ ] All post-deployment checks pass
- [ ] Monitoring alerts configured
- [ ] Rollback procedure documented and tested (in staging)
- [ ] Team trained on rollback procedure

---

## Timeline

| Phase | Duration | ETA |
|-------|----------|-----|
| Phase 1: Development Testing | 30 min | 2025-10-29 14:00 |
| Phase 2: Staging Deployment | 1 hour | 2025-10-29 16:00 |
| Phase 3: Production Deployment | 30 min | 2025-10-30 10:00 |
| Total | 2 hours | - |

**Critical Path:** Development testing → Staging validation → Production deployment

**Dependencies:**
- Database access for testing
- Staging environment availability
- Production maintenance window approval

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Migration fails in production | LOW | HIGH | Test in staging first, have rollback ready |
| Data corruption during migration | VERY LOW | CRITICAL | Migration is idempotent, database backup |
| Service downtime during deployment | LOW | MEDIUM | Schedule maintenance window, quick rollback |
| Validation trigger breaks existing flows | VERY LOW | HIGH | Test extensively in staging |
| Rollback needed | LOW | MEDIUM | Documented procedure, <5 min rollback time |

**Overall Risk:** LOW - Migration is well-tested and has clear rollback path

---

## Approval Required

**Reviewer:** Data Integrity Guardian
**Status:** ⚠️ AWAITING APPROVAL

**Approve to proceed with:**
1. [ ] Execute Phase 1 (Development Testing)
2. [ ] Execute Phase 2 (Staging Deployment)
3. [ ] Schedule Phase 3 (Production Deployment)

**Questions/Concerns:**
- (Add any questions or concerns here before approval)

**Approved By:** ___________________
**Date:** ___________________
**Signature:** ___________________

---

## Post-Deployment Review

**To be completed after production deployment:**

- [ ] Migration applied successfully: YES / NO / ROLLBACK
- [ ] All validation checks passed: YES / NO
- [ ] Any issues encountered: (describe)
- [ ] Rollback performed: YES / NO
- [ ] Total downtime: _____ minutes
- [ ] Lessons learned: (list)
- [ ] Follow-up actions: (list)

---

**Document Version:** 1.0
**Last Updated:** 2025-10-29
**Owner:** Data Integrity Guardian
**Next Review:** After production deployment
