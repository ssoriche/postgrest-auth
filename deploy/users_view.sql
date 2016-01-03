-- Deploy postgrest-auth:users_view to pg
-- requires: users_base_view

BEGIN;

  CREATE OR REPLACE VIEW auth.users AS
    SELECT
        id,
        username,
        facebook_token,
        email,
        encrypted_password,
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
        'member'::name AS role,
        created_at,
        updated_at
      FROM auth.users_base
      WITH CHECK OPTION
  ;

COMMIT;
