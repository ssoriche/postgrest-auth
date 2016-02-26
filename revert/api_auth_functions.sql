-- Revert postgrest-auth:api_auth_functions from pg

BEGIN;
  SET client_min_messages TO WARNING;

  DROP FUNCTION IF EXISTS public.request_password_reset(TEXT);
  DROP FUNCTION IF EXISTS public.reset_password(TEXT, UUID, TEXT);
  DROP FUNCTION IF EXISTS public.signup(TEXT, TEXT);
  DROP FUNCTION IF EXISTS public.login(TEXT, TEXT);
  DROP FUNCTION IF EXISTS public.confirm(UUID);
  DROP FUNCTION IF EXISTS public.change_password(TEXT, TEXT, TEXT, TEXT);

COMMIT;
