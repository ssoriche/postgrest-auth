-- Revert postgrest-auth:auth_functions from pg

BEGIN;

  DROP TRIGGER IF EXISTS ensure_user_role_exists ON auth.user_roles;
  DROP TRIGGER IF EXISTS ensure_user_user_exists ON auth.user_roles;
  DROP TRIGGER IF EXISTS users_trigger on auth.users;

COMMIT;
