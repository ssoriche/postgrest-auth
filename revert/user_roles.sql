-- Revert postgrest-auth:user_roles from pg

BEGIN;

  DROP TABLE IF EXISTS auth.user_roles;

COMMIT;
