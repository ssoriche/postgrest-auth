-- Verify postgrest-auth:external_functions on pg

BEGIN;

  SELECT has_function_privilege('auth.request_password_reset(text)', 'execute');
  SELECT has_function_privilege('auth.reset_password(text,uuid,text)', 'execute');
  SELECT has_function_privilege('auth.signup(text,text,text,text)', 'execute');
  SELECT has_function_privilege('auth.confirm(UUID,TEXT)', 'execute');
  SELECT has_function_privilege('auth.login(text,text,integer)', 'execute');
  SELECT has_function_privilege('auth.change_password(TEXT, TEXT, TEXT, TEXT)','execute');

ROLLBACK;

