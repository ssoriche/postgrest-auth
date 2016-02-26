-- Verify postgrest-auth:api_auth_functions on pg

BEGIN;

  SELECT has_function_privilege('public.request_password_reset(TEXT)','execute');
  SELECT has_function_privilege('public.reset_password(TEXT, UUID, TEXT)','execute');
  SELECT has_function_privilege('public.signup(TEXT, TEXT)','execute');
  SELECT has_function_privilege('public.login(TEXT, TEXT)','execute');
  SELECT has_function_privilege('public.confirm(UUID)','execute');
  SELECT has_function_privilege('public.change_password(TEXT, TEXT, TEXT, TEXT)','execute');

ROLLBACK;
