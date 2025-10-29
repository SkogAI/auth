# SAML Authentication - Production Readiness Tracker

**Epic tracking post-integration hardening and production readiness improvements**

## Context

SAML authentication is **functionally complete** with end-to-end tests passing (13/13 automated, 5/5 manual). This document tracks security hardening and architecture improvements required before production deployment.

**Review Date**: 2025-10-29
**Branch**: test-claude-commands
**Full Report**: `/tmp/code-review-findings.md`

---

## Issues Summary

**GitHub Issues Created**: [View all issues](https://github.com/SkogAI/auth/issues)

### 🟠 HIGH Priority (P1) - **Required for Production**

#### Issue #2: Missing CSRF Protection on SAML ACS Endpoint
**GitHub**: [#1](https://github.com/SkogAI/auth/issues/1)
- **Location**: `internal/api/samlacs.go:98`
- **Impact**: CSRF attacks, session fixation (OWASP A01:2021)
- **Effort**: Medium (8-16 hours)
- **Status**: ⏳ TODO comment exists in code
- **Blocking**: Yes - required before production

**Problem**: TODO comment indicates CSRF token binding not implemented:
```go
// TODO: Bind CSRF token to the RelayState to prevent CSRF attacks
```

**Solution**:
1. Generate cryptographically random CSRF token during SSO initiation
2. Store token-to-session mapping (120s expiry)
3. Include token in RelayState parameter
4. Validate token on ACS callback (constant-time comparison)

```go
// Example implementation
csrfToken := generateSecureToken()
storeTokenWithExpiry(csrfToken, 120*time.Second)
relayState := fmt.Sprintf("%s:%s", flowStateID, csrfToken)

// In ACS handler
parts := strings.Split(relayState, ":")
if !constantTimeCompare(parts[1], expectedToken) {
    return errors.New("CSRF token validation failed")
}
```

---

#### Issue #3: Insufficient Rate Limiting on Auth Endpoints
**GitHub**: [#2](https://github.com/SkogAI/auth/issues/2)
- **Location**: `/sso`, `/sso/saml/acs`, `/token` endpoints
- **Impact**: DoS via resource exhaustion, brute force attacks
- **Effort**: Medium (16 hours)
- **Status**: ⏳ No rate limiting implemented
- **Blocking**: Yes - required before production

**Problem**: No rate limiting on CPU-intensive endpoints:
- `/sso` - SSO initiation
- `/sso/saml/acs` - Assertion processing (XML parsing + crypto validation)
- `/token` - Token issuance

**Solution**:
1. Rate limiting middleware (5 req/min per IP for /sso)
2. Exponential backoff for failed auth attempts
3. Circuit breaker for XML parsing (prevent XML bombs)
4. Request size limits (max 1MB for SAML assertions)

---

### 🟡 MEDIUM Priority (P2) - **Recommended Improvements**

#### Issue #4: Missing Migration for attribute_mapping Fix
**GitHub**: [#4](https://github.com/SkogAI/auth/issues/4)
- **Location**: Commit `a34c1750` bypassed migration framework
- **Impact**: Fresh deployments will fail with JSON unmarshal error
- **Effort**: Small (4 hours)
- **Status**: ⏳ Direct UPDATE applied, need retroactive migration
- **Blocking**: No - but recommended before next deployment

**Problem**: Bug fix applied via direct SQL UPDATE instead of migration:
```sql
UPDATE auth.saml_providers
SET attribute_mapping = '{"keys": {...}}'
WHERE id = '25cafa85-9f80-4186-b55e-0941767774c7';
```

**Solution**: Create retroactive migration `migrations/20251029120000_fix_saml_attribute_mapping.up.sql`:
```sql
UPDATE auth.saml_providers
SET attribute_mapping = jsonb_set(
    attribute_mapping,
    '{keys}',
    (
        SELECT jsonb_object_agg(
            key,
            jsonb_build_object('name', value)
        )
        FROM jsonb_each_text(attribute_mapping->'keys')
    )
)
WHERE attribute_mapping->'keys' IS NOT NULL
AND jsonb_typeof(attribute_mapping->'keys') = 'object';
```

---

#### Issue #5: Undefined 24-Service Integration Pattern
**GitHub**: [#5](https://github.com/SkogAI/auth/issues/5)
- **Location**: `SAML_CONFIG_STATUS.md:417`
- **Impact**: Blocked migration of 24 downstream services
- **Effort**: Large (40 hours)
- **Status**: ⏳ Goal stated, pattern undefined
- **Blocking**: No - but blocks service migration

**Problem**: Documentation states goal to "consolidate 24 separate Zitadel SAML integrations" but no integration pattern defined:
- How will services validate JWT tokens? (shared secret vs JWKS)
- Token refresh strategy?
- Service discovery mechanism?
- Migration plan from direct Zitadel integration?

**Solution**: Create ADR defining:
1. JWT validation strategy (recommend JWKS endpoint at `/.well-known/jwks.json`)
2. Token refresh flow with automatic expiry handling
3. Service discovery (recommend DNS with fallback to config)
4. Migration phases with rollback plan:
   - Phase 1: Pilot with 2-3 services
   - Phase 2: Batch migration (5 services per week)
   - Phase 3: Deprecate direct Zitadel integrations
5. Reference implementations (Go, Node.js, Python)

**Example Go validation**:
```go
import "github.com/golang-jwt/jwt/v4"

func ValidateToken(tokenString string) (*Claims, error) {
    token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
        // Fetch JWKS and validate signature
        return fetchJWKS("https://auth.skogai.se/.well-known/jwks.json")
    })

    if err != nil || !token.Valid {
        return nil, errors.New("invalid token")
    }

    return token.Claims.(*Claims), nil
}
```

---

#### Issue #6: No High Availability or Failover Strategy
**GitHub**: [#6](https://github.com/SkogAI/auth/issues/6)
- **Location**: Infrastructure (single auth instance + single DB)
- **Impact**: Auth service failure blocks all 24 downstream services
- **Effort**: Large (80 hours)
- **Status**: ⏳ Single points of failure exist
- **Blocking**: No - but recommended for production

**Problem**: Single points of failure:
- Single auth service instance (PID 811804)
- Single PostgreSQL database (localhost:5432)
- No health checks or monitoring
- No automatic failover

**Impact**: If auth service fails, all 24 downstream services lose authentication.

**Solution**:
1. **Database HA**:
   - PostgreSQL streaming replication (1 primary + 2 replicas)
   - Patroni for automatic failover (RPO: 0 seconds, RTO: < 30 seconds)
   - Connection pooling with PgBouncer

2. **Service HA**:
   - Multiple auth service instances (min 3 for quorum)
   - Load balancer with health checks (nginx or HAProxy)
   - Session affinity for in-flight SAML flows

3. **Health Checks**:
   - `/health` endpoint returning 200 if:
     - Database connectivity OK
     - SAML private key loadable
     - Disk space > 20%
   - Liveness probe: `/health` every 10s
   - Readiness probe: `/health` before routing traffic

4. **Monitoring**:
   - Prometheus metrics:
     - `auth_requests_total` (counter by endpoint, status)
     - `auth_request_duration_seconds` (histogram)
     - `auth_active_sessions` (gauge)
     - `auth_database_connections` (gauge)
   - Grafana dashboards:
     - Request rate and latency
     - Error rate (5xx responses)
     - Database connection pool utilization
     - Session count trends

5. **Alerting**:
   - PagerDuty integration for critical alerts:
     - Service down (all instances)
     - Database unreachable
     - Error rate > 5%
     - Response latency p99 > 1s

**Architecture Diagram**:
```
                    ┌─────────────┐
                    │   Clients   │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │   nginx LB  │
                    │ (health chk)│
                    └──┬───┬───┬──┘
           ┌───────────┼───┼───┼───────────┐
           │           │   │   │           │
      ┌────▼────┐ ┌────▼───▼───▼────┐ ┌───▼────┐
      │ Auth #1 │ │    Auth #2      │ │Auth #3 │
      │(primary)│ │   (standby)     │ │(hot)   │
      └────┬────┘ └────┬────────┬───┘ └───┬────┘
           │           │        │         │
           └───────┬───┴────────┴─────┬───┘
                   │                  │
            ┌──────▼──────┐    ┌──────▼──────┐
            │  PostgreSQL │    │  PostgreSQL │
            │   Primary   │───▶│   Replica   │
            │  (Patroni)  │    │  (standby)  │
            └─────────────┘    └─────────────┘
```

---

#### Issue #7: Overly Permissive CORS Configuration
**GitHub**: [#3](https://github.com/SkogAI/auth/issues/3)
- **Location**: `.env` - `GOTRUE_CORS_ALLOWED_ORIGINS="*"`
- **Impact**: Increased XSS attack surface, complicates CSRF defenses
- **Effort**: Small (2 hours)
- **Status**: ⏳ Wildcard allows any origin
- **Blocking**: Yes - should restrict before production

**Problem**: Current configuration allows any origin to make authenticated requests:
```bash
GOTRUE_CORS_ALLOWED_ORIGINS="*"
```

**Solution**: Whitelist specific origins:
```bash
# Production
GOTRUE_CORS_ALLOWED_ORIGINS="https://studio.skogai.se,https://app.skogai.se,https://api.skogai.se"

# Development (add localhost)
GOTRUE_CORS_ALLOWED_ORIGINS="https://studio.skogai.se,https://app.skogai.se,http://localhost:8080,http://localhost:3000"
```

**Testing**:
```bash
# Should succeed (whitelisted origin)
curl -H "Origin: https://studio.skogai.se" https://auth.skogai.se/health

# Should fail (non-whitelisted origin)
curl -H "Origin: https://evil.com" https://auth.skogai.se/health
```

---

#### Issue #8: Weak RelayState Validation (Timing Attack)
**GitHub**: [#7](https://github.com/SkogAI/auth/issues/7)
- **Location**: `internal/api/samlacs.go:90-96`
- **Impact**: Attacker can use timing differences to guess valid RelayState values
- **Effort**: Small (4 hours)
- **Status**: ⏳ String comparison timing leak
- **Blocking**: No - but recommended security hardening

**Problem**: RelayState expiry check uses standard comparison vulnerable to timing attacks:
```go
if time.Now().After(expiresAt) {
    return errors.New("RelayState has expired")
}
```

Attacker can measure response time differences to determine if RelayState is close to expiry.

**Solution**: Add random jitter to mask timing:
```go
// Add random jitter (0-100ms) to expiry checks
jitter := time.Duration(rand.Int63n(100)) * time.Millisecond
if time.Now().Add(jitter).After(expiresAt) {
    return errors.New("RelayState has expired")
}
```

---

### 🔴 CRITICAL (P0) - **Risk Accepted**

#### Issue #1: Cryptographic Secrets in Git History
- **Location**: `certs/` directory committed to git (commit 717db165)
- **Impact**: Complete authentication bypass, user impersonation, GDPR violation
- **Effort**: Large (24 hours immediate + 1 week full remediation)
- **Status**: ⚠️ **RISK ACCEPTED by maintainer**
- **Blocking**: N/A (decision made)

**Exposed Secrets**:
- `certs/keys.txt` - OAuth Client ID and Client Secret
- `certs/saml_private_key.pem` - SAML SP private key (RSA 2048-bit)
- `certs/saml_private_key_pkcs1.pem` - Same key, PKCS#1 format
- `certs/saml_private_key.der` - Same key, DER encoding

**Risk Assessment**:
- Anyone with repository access can extract these secrets from git history permanently
- Secrets cannot be removed from history without force-push or repository migration
- Current deployment appears to be dev/test environment based on user decision

**Recommendation if Reconsidered**:
1. **IMMEDIATE**: Rotate all exposed secrets
   - Generate new SAML key pair: `openssl genrsa -out new_private_key.pem 2048`
   - Update Zitadel with new certificate
   - Generate new OAuth Client Secret in Zitadel
2. **SHORT-TERM**: Add `certs/` to `.gitignore`
3. **LONG-TERM**: Consider repository migration (history permanently compromised)
4. **ONGOING**: Implement secrets management (Vault, AWS Secrets Manager)

---

## Production Readiness Checklist

### 🔴 Blocking Issues (Must Fix Before Production)
- [ ] Implement CSRF protection ([#1](https://github.com/SkogAI/auth/issues/1))
- [ ] Add rate limiting ([#2](https://github.com/SkogAI/auth/issues/2))
- [ ] Restrict CORS origins ([#3](https://github.com/SkogAI/auth/issues/3))

### 🟡 Recommended Before Launch
- [ ] Create attribute_mapping migration ([#4](https://github.com/SkogAI/auth/issues/4))
- [ ] Define service integration pattern ([#5](https://github.com/SkogAI/auth/issues/5))
- [ ] Fix timing attack vulnerability ([#7](https://github.com/SkogAI/auth/issues/7))

### ⚪ Post-Launch (Can Defer)
- [ ] Implement HA/failover strategy ([#6](https://github.com/SkogAI/auth/issues/6))
- [ ] Rotate exposed secrets (Risk accepted - reconsider if moving to production)

---

## Current Status

✅ **Functional**: SAML authentication working end-to-end
✅ **Tested**: All automated (13/13) and manual (5/5) tests passing
✅ **Code Quality**: Go fmt/vet/staticcheck clean
⚠️ **Security**: 2 HIGH severity issues require fixes (CSRF, rate limiting)
⚠️ **Architecture**: Scalability and HA undefined

**Test Artifacts**:
- ✅ Studio login UI: `/tmp/studio-login.html`
- ✅ Studio dashboard UI: `/tmp/studio-dashboard.html`
- ✅ Integration guide: `/tmp/STUDIO_AUTH_INTEGRATION.md`
- ✅ Database verified: User creation, identity linking, session management all working
- ✅ JWT tokens: Valid 1-hour expiry, refresh tokens issued

**Successful Test User**:
- Email: `emil@skogsund.se`
- User ID: `55057807-00d2-4e14-8280-84878ede1066`
- Identity Provider: Zitadel (`sso:a1d79e11-0000-0000-0000-000000000001`)
- Auth Method: `sso/saml`
- Session established: Yes

---

## Review Statistics

**Automated Tests**: 13/13 passed (100%)
**Manual Tests**: 5/5 passed (100%)
**Code Quality**: Go fmt/vet/staticcheck clean

**Security Findings**:
- 🔴 1 CRITICAL (accepted risk)
- 🟠 2 HIGH (require fixes)
- 🟡 5 MEDIUM (recommended improvements)

**Architecture Maturity**:
- ✅ Core functionality complete
- ⚠️ Production readiness: Requires HA + monitoring
- ⚠️ Scalability: Untested at scale (recommend load testing with 1000 req/s)
- ⚠️ Documentation: Integration pattern undefined

---

## Related Documentation

- `SAML_CONFIG_STATUS.md` - Complete SAML configuration and service status
- `TESTING_SUMMARY.md` - Detailed test results and database verification
- `/tmp/code-review-findings.md` - Comprehensive security/architecture review
- `/tmp/STUDIO_AUTH_INTEGRATION.md` - Frontend integration guide with code examples
- `/tmp/serve-studio.sh` - Local testing web server

---

## Next Steps

### Immediate Actions (This Week)
1. **Implement CSRF protection** ([#1](https://github.com/SkogAI/auth/issues/1))
   - Add token generation in SSO initiation
   - Store token with 120s expiry
   - Validate on ACS callback
   - Test with studio login flow

2. **Add rate limiting** ([#2](https://github.com/SkogAI/auth/issues/2))
   - Implement middleware with per-IP limits
   - Configure thresholds (5 req/min for /sso)
   - Add exponential backoff for failed auth
   - Test with load simulation

3. **Restrict CORS** ([#3](https://github.com/SkogAI/auth/issues/3))
   - Update `.env` with whitelisted origins
   - Test studio login still works
   - Verify other origins are blocked

### Short-term (Next Sprint)
4. **Create attribute_mapping migration** ([#4](https://github.com/SkogAI/auth/issues/4))
5. **Fix timing attack** ([#7](https://github.com/SkogAI/auth/issues/7))
6. **Document integration pattern** ([#5](https://github.com/SkogAI/auth/issues/5))

### Long-term (Next Quarter)
7. **Implement HA strategy** ([#6](https://github.com/SkogAI/auth/issues/6))
8. **Conduct load testing** (target: 1000 req/s)
9. **Set up monitoring and alerting**

---

**Last Updated**: 2025-10-29
**Review Method**: Multi-agent analysis (Security Sentinel, Architecture Strategist, Data Integrity Guardian)
**Maintainer**: SkogAI Team
