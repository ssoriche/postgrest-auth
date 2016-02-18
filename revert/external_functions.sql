-- Revert postgrest-auth:external_functions from pg

BEGIN;

  DROP FUNCTION IF EXISTS auth.login(TEXT, TEXT, INTEGER, OUT auth.jwt_claims);
  DROP FUNCTION IF EXISTS auth.confirm(UUID);

COMMIT;
