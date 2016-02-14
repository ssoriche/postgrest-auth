-- Revert postgrest-auth:auth_functions from pg

BEGIN;

  DROP TRIGGER IF EXISTS ensure_user_role_exists ON auth.user_roles;
  DROP TRIGGER IF EXISTS ensure_user_user_exists ON auth.user_roles;
  DROP TRIGGER IF EXISTS auth_users_add on auth.users;
  DROP TRIGGER IF EXISTS auth_users_change on auth.users;

  DROP FUNCTION IF EXISTS auth.user_role(text, text);
  DROP FUNCTION IF EXISTS auth.users_add();
  DROP FUNCTION IF EXISTS auth.users_change();
  DROP FUNCTION IF EXISTS auth.request_password_reset(TEXT);

COMMIT;
