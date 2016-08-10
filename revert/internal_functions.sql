-- Revert postgrest-auth:auth_functions from pg

BEGIN;

  DROP TRIGGER IF EXISTS auth_users_add on auth.users;
  DROP TRIGGER IF EXISTS auth_users_change on auth.users;

  DROP FUNCTION IF EXISTS auth.user_role(text, text);
  DROP FUNCTION IF EXISTS auth.users_add();
  DROP FUNCTION IF EXISTS auth.users_change();
  DROP FUNCTION IF EXISTS auth.clearance_for_role(name);
  DROP FUNCTION IF EXISTS auth.check_role_exists(text);

  DROP TYPE IF EXISTS auth.jwt_claims CASCADE;

COMMIT;
