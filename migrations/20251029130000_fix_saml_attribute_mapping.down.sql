-- Rollback validation trigger and function
-- Note: We do NOT revert the data fix as the original format was incorrect
-- and would break SAML authentication

DROP TRIGGER IF EXISTS validate_saml_attribute_mapping_trigger ON {{ index .Options "Namespace" }}.saml_providers;

DROP FUNCTION IF EXISTS {{ index .Options "Namespace" }}.validate_saml_attribute_mapping();

-- WARNING: The following commented-out code would revert the data fix
-- Uncommenting and running this will BREAK SAML authentication by reverting
-- to the incorrect JSON structure that causes "cannot unmarshal string" errors
--
-- DO NOT UNCOMMENT unless you are certain you want to break SAML:
--
-- UPDATE {{ index .Options "Namespace" }}.saml_providers
-- SET attribute_mapping = (
--   SELECT jsonb_build_object(
--     'keys',
--     jsonb_object_agg(key, value->>'name')
--   )
--   FROM jsonb_each(attribute_mapping->'keys')
-- )
-- WHERE attribute_mapping IS NOT NULL
--   AND EXISTS (
--     SELECT 1
--     FROM jsonb_each(attribute_mapping->'keys') AS kv
--     WHERE jsonb_typeof(kv.value) = 'object'
--       AND (kv.value ? 'name')
--   );
