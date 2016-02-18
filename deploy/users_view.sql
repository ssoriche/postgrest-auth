-- Deploy postgrest-auth:users_view to pg
-- requires: users_base_view

BEGIN;
  SET client_min_messages TO WARNING;

  CREATE OR REPLACE VIEW auth.users AS
    SELECT
        base.id,
        base.username,
        base.facebook_token,
        base.email,
        base.pass,
        base.reset_password_token,
        base.reset_password_sent_at,
        base.remember_created_at,
        base.sign_in_count,
        base.current_sign_in_at,
        base.last_sign_in_at,
        base.current_sign_in_ip,
        base.last_sign_in_ip,
        base.confirmation_token,
        base.confirmed_at,
        base.confirmation_sent_at,
        base.failed_attempts,
        base.unlock_token,
        base.locked_at,
        role.role AS role,
        base.created_at,
        base.updated_at
      FROM auth.users_base base
      INNER JOIN auth.user_roles role
        ON base.id = role.user_id
  ;

COMMIT;
