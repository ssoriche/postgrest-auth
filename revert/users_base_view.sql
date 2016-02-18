-- Revert postgrest-auth:users_base_view from pg

BEGIN;

  DROP VIEW IF EXISTS auth.users_attributes_base;
  DROP VIEW IF EXISTS auth.users_base;

COMMIT;
