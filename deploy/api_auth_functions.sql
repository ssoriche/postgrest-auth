-- Deploy postgrest-auth:api_auth_functions to pg

BEGIN;
  SET client_min_messages TO WARNING;

  CREATE OR REPLACE FUNCTION public.request_password_reset(email TEXT) RETURNS VOID AS $$
    BEGIN
      PERFORM auth.request_password_reset(request_password_reset.email);
    END;
  $$ LANGUAGE plpgsql;

  CREATE OR REPLACE FUNCTION public.reset_password(email TEXT, token UUID, pass TEXT) RETURNS VOID AS $$
    BEGIN
      PERFORM auth.reset_password(reset_password.email, reset_password.token, reset_password.pass);
    END;
  $$ LANGUAGE plpgsql;

  CREATE OR REPLACE FUNCTION public.signup(email TEXT, pass TEXT) RETURNS VOID AS $$
    BEGIN
      PERFORM auth.signup(signup.email, signup.email, signup.pass, 'unverified');
    END;
  $$ LANGUAGE plpgsql;

  CREATE OR REPLACE FUNCTION public.login(email TEXT, pass TEXT) RETURNS auth.jwt_claims AS $$
    BEGIN
      RETURN auth.login(login.email, login.pass);
    END;
  $$ LANGUAGE plpgsql;

  CREATE OR REPLACE FUNCTION public.confirm(token UUID) RETURNS VOID AS $$
    BEGIN
      PERFORM auth.confirm(confirm.token, 'member');
    END;
  $$ LANGUAGE plpgsql;

  CREATE OR REPLACE FUNCTION public.change_password(email TEXT, current_password TEXT, new_password TEXT, confirm_password TEXT) RETURNS void AS $$
    BEGIN
      PERFORM auth.change_password(change_password.email, change_password.current_password, change_password.new_password, change_password.confirm_password);
    END;
  $$ LANGUAGE plpgsql;

COMMIT;
