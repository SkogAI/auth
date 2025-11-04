-- Cleanup script for orphaned non-SSO user
-- Run this manually before production deployment
--
-- User: 3dba10e7-a636-442f-baf5-18331368aa51
-- Email: emil@skogsund.se
-- Type: Non-SSO user (is_sso_user = false)
-- Status: No identities, no sessions, no refresh tokens
--
-- This user was created during initial SAML testing before SSO provider
-- was properly configured. The user never completed authentication flow.

BEGIN;

-- Verify the user has no associated data
DO $$
DECLARE
  target_user_id UUID := '3dba10e7-a636-442f-baf5-18331368aa51';
  identity_count INTEGER;
  session_count INTEGER;
  token_count INTEGER;
BEGIN
  -- Check for identities
  SELECT COUNT(*) INTO identity_count
  FROM auth.identities
  WHERE user_id = target_user_id;

  -- Check for sessions
  SELECT COUNT(*) INTO session_count
  FROM auth.sessions
  WHERE user_id = target_user_id;

  -- Check for refresh tokens
  SELECT COUNT(*) INTO token_count
  FROM auth.refresh_tokens rt
  JOIN auth.sessions s ON rt.session_id = s.id
  WHERE s.user_id = target_user_id;

  -- Abort if user has any associated data
  IF identity_count > 0 THEN
    RAISE EXCEPTION 'User % has % identities - manual review required', target_user_id, identity_count;
  END IF;

  IF session_count > 0 THEN
    RAISE EXCEPTION 'User % has % sessions - manual review required', target_user_id, session_count;
  END IF;

  IF token_count > 0 THEN
    RAISE EXCEPTION 'User % has % refresh tokens - manual review required', target_user_id, token_count;
  END IF;

  RAISE NOTICE 'User % is safe to delete (no associated data)', target_user_id;
END;
$$;

-- Delete the orphaned user
DELETE FROM auth.users
WHERE id = '3dba10e7-a636-442f-baf5-18331368aa51'
  AND is_sso_user = false
  AND email = 'emil@skogsund.se';

-- Verify deletion
DO $$
DECLARE
  deleted_count INTEGER;
BEGIN
  GET DIAGNOSTICS deleted_count = ROW_COUNT;

  IF deleted_count = 0 THEN
    RAISE WARNING 'User was not deleted - may have already been removed or conditions not met';
  ELSIF deleted_count = 1 THEN
    RAISE NOTICE 'Successfully deleted orphaned user 3dba10e7-a636-442f-baf5-18331368aa51';
  ELSE
    RAISE EXCEPTION 'Unexpected: deleted % rows (expected 0 or 1)', deleted_count;
  END IF;
END;
$$;

COMMIT;

-- Post-deletion verification
SELECT
  'Users with email emil@skogsund.se' as check_type,
  COUNT(*) as count,
  STRING_AGG(id::text, ', ') as user_ids
FROM auth.users
WHERE email = 'emil@skogsund.se';
