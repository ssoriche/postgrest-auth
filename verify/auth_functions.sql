-- Verify postgrest-auth:auth_functions on pg

BEGIN;

  SELECT has_function_privilege('auth.user_role(text, text)', 'execute');

ROLLBACK;
