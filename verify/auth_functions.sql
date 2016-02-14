-- Verify postgrest-auth:auth_functions on pg

BEGIN;

  SELECT has_function_privilege('auth.check_role_exists()', 'execute');
  SELECT has_function_privilege('auth.check_user_exists()', 'execute');
  SELECT has_function_privilege('auth.users_add()', 'execute');
  SELECT has_function_privilege('auth.users_change()', 'execute');
  SELECT has_function_privilege('auth.user_role(text, text)', 'execute');
  SELECT has_function_privilege('auth.request_password_reset(text)', 'execute');

ROLLBACK;
