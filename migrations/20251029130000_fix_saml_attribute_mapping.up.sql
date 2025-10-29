-- Fix attribute_mapping structure for existing SAML providers
-- This migration ensures all attribute_mapping values conform to SAMLAttribute struct format
--
-- Background:
-- The attribute_mapping column in saml_providers stores a JSON structure that maps
-- SAML attributes to user fields. The Go code expects this structure:
--   {"keys": {"email": {"name": "Email"}}}
--
-- However, the column was created with this incorrect structure:
--   {"keys": {"email": "Email"}}
--
-- This caused database scan errors: "json: cannot unmarshal string into Go struct field"
--
-- This migration fixes any existing malformed entries and adds validation to prevent
-- future issues.

-- Step 1: Fix existing malformed attribute_mapping values
-- Convert string values to SAMLAttribute struct format: {"name": "AttributeName"}
UPDATE {{ index .Options "Namespace" }}.saml_providers
SET attribute_mapping = jsonb_set(
  '{"keys": {}}'::jsonb,
  '{keys}',
  (
    SELECT jsonb_object_agg(
      key,
      CASE
        -- If value is a string, wrap it in {"name": ...} structure
        WHEN jsonb_typeof(value) = 'string'
          THEN jsonb_build_object('name', value)
        -- If already an object, keep as-is
        ELSE value
      END
    )
    FROM jsonb_each(attribute_mapping->'keys')
  )
)
WHERE attribute_mapping IS NOT NULL
  AND EXISTS (
    -- Only update if there are string values (malformed entries)
    SELECT 1
    FROM jsonb_each(attribute_mapping->'keys') AS kv
    WHERE jsonb_typeof(kv.value) = 'string'
  );

-- Step 2: Create validation function to ensure proper structure
CREATE OR REPLACE FUNCTION {{ index .Options "Namespace" }}.validate_saml_attribute_mapping()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.attribute_mapping IS NOT NULL THEN
    -- Check that 'keys' exists and is an object
    IF NOT (NEW.attribute_mapping ? 'keys') THEN
      RAISE EXCEPTION 'attribute_mapping must have a "keys" field';
    END IF;

    IF jsonb_typeof(NEW.attribute_mapping->'keys') != 'object' THEN
      RAISE EXCEPTION 'attribute_mapping.keys must be an object';
    END IF;

    -- Check that all values under 'keys' are objects with 'name' field
    IF EXISTS (
      SELECT 1
      FROM jsonb_each(NEW.attribute_mapping->'keys') AS kv
      WHERE jsonb_typeof(kv.value) != 'object'
         OR NOT (kv.value ? 'name')
         OR jsonb_typeof(kv.value->'name') != 'string'
    ) THEN
      RAISE EXCEPTION 'attribute_mapping.keys values must be objects with "name" field (string): {"name": "AttributeName"}';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION {{ index .Options "Namespace" }}.validate_saml_attribute_mapping() IS 'Auth: Validates that SAML attribute_mapping has correct structure for Go unmarshaling into models.SAMLAttributeMapping';

-- Step 3: Create trigger to validate on INSERT/UPDATE
DROP TRIGGER IF EXISTS validate_saml_attribute_mapping_trigger ON {{ index .Options "Namespace" }}.saml_providers;

CREATE TRIGGER validate_saml_attribute_mapping_trigger
  BEFORE INSERT OR UPDATE OF attribute_mapping ON {{ index .Options "Namespace" }}.saml_providers
  FOR EACH ROW
  EXECUTE FUNCTION {{ index .Options "Namespace" }}.validate_saml_attribute_mapping();

COMMENT ON TRIGGER validate_saml_attribute_mapping_trigger ON {{ index .Options "Namespace" }}.saml_providers IS 'Auth: Prevents insertion of malformed attribute_mapping JSON that would cause Go unmarshal errors';
