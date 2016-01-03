-- Revert postgrest-auth:users_base_view from pg

BEGIN;

  DROP VIEW auth.users_base;

COMMIT;
