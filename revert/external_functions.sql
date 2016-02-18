-- Revert postgrest-auth:external_functions from pg

BEGIN;

  DROP FUNCTION IF EXISTS auth.request_password_reset(TEXT);
  DROP FUNCTION IF EXISTS auth.reset_password(TEXT, UUID, TEXT);
  DROP FUNCTION IF EXISTS auth.signup(TEXT, TEXT, TEXT, TEXT);
  DROP FUNCTION IF EXISTS auth.login(TEXT, TEXT, INTEGER, OUT auth.jwt_claims);
  DROP FUNCTION IF EXISTS auth.confirm(UUID);

COMMIT;
