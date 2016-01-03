-- Revert postgrest-auth:users_view from pg

BEGIN;

  DROP VIEW auth.users;

COMMIT;
