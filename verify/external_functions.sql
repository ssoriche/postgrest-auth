-- Verify postgrest-auth:external_functions on pg

BEGIN;

  SELECT has_function_privilege('auth.confirm(UUID)', 'execute');
  SELECT has_function_privilege('auth.login(text,text,integer)', 'execute');

ROLLBACK;

