-- Deploy postgrest-auth:users_base_view to pg
-- requires: auth_schema

BEGIN;
  SET client_min_messages TO WARNING;

  CREATE OR REPLACE VIEW auth.users_base AS
    SELECT
        id,
        username,
        facebook_token,
        email,
        encrypted_password AS pass,
        reset_password_token,
        reset_password_sent_at,
        remember_created_at,
        sign_in_count,
        current_sign_in_at,
        last_sign_in_at,
        current_sign_in_ip,
        last_sign_in_ip,
        confirmation_token,
        confirmed_at,
        confirmation_sent_at,
        failed_attempts,
        unlock_token,
        locked_at,
        created_at,
        updated_at
      FROM devise_test.users
      WHERE ( email ~* '^.+@.+\..+$' )
        AND (length(encrypted_password) < 512)
      WITH CHECK OPTION
  ;

  CREATE OR REPLACE VIEW auth.users_attributes_base AS
    SELECT
        username,
        facebook_token,
        email,
        pass,
        reset_password_token,
        reset_password_sent_at,
        remember_created_at,
        sign_in_count,
        current_sign_in_at,
        last_sign_in_at,
        current_sign_in_ip,
        last_sign_in_ip,
        confirmation_token,
        confirmed_at,
        confirmation_sent_at,
        failed_attempts,
        unlock_token,
        locked_at,
        created_at,
        updated_at
      FROM auth.users_base
  ;

COMMIT;
