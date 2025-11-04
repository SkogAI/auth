-- Cleanup script for expired SAML relay states
-- Run this periodically to prevent table bloat
--
-- SAML relay states are temporary records created during SSO initiation.
-- They should be cleaned up after the authentication flow completes or expires.
--
-- Relay State Validity Period: 120s (from .env: GOTRUE_SAML_RELAY_STATE_VALIDITY_PERIOD)
-- Cleanup Threshold: 2 hours (conservative, allows for debugging)

BEGIN;

-- Show current relay state count
SELECT
  sso_provider_id,
  COUNT(*) as total_states,
  COUNT(*) FILTER (WHERE created_at < NOW() - INTERVAL '2 hours') as expired_states,
  MIN(created_at) as oldest_state,
  MAX(created_at) as newest_state
FROM auth.saml_relay_states
GROUP BY sso_provider_id;

-- Delete expired relay states (older than 2 hours)
DELETE FROM auth.saml_relay_states
WHERE created_at < NOW() - INTERVAL '2 hours';

-- Report deletion count
DO $$
DECLARE
  deleted_count INTEGER;
BEGIN
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RAISE NOTICE 'Deleted % expired SAML relay states', deleted_count;
END;
$$;

-- Show updated relay state count
SELECT
  sso_provider_id,
  COUNT(*) as remaining_states,
  MIN(created_at) as oldest_state,
  MAX(created_at) as newest_state
FROM auth.saml_relay_states
GROUP BY sso_provider_id;

COMMIT;
