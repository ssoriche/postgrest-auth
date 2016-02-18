-- Deploy postgrest-auth:external_functions to pg
-- requires: internal_functions

BEGIN;
  SET client_min_messages TO WARNING;

  CREATE OR REPLACE FUNCTION auth.login(identifier TEXT, pass TEXT, exp INTEGER=NULL) RETURNS auth.jwt_claims AS $$
    DECLARE
      _role name;
      result auth.jwt_claims;
    BEGIN
      SELECT auth.user_role(login.identifier, pass) INTO _role;
      IF _role IS NULL THEN
        RAISE invalid_password USING message = 'invalid user or password';
      END IF;

      SELECT
          _role AS role,
          users.id AS user_id,
          users.username AS username,
          users.email AS email,
          CASE
            WHEN login.exp IS NOT NULL THEN ROUND(EXTRACT(epoch FROM now())) + login.exp * 60
            ELSE NULL
          END as exp
        INTO result
        FROM auth.users
        WHERE login.identifier IN (username, email)
          AND confirmation_token IS NULL
          AND confirmed_at IS NOT NULL
        ;

      IF result.user_id IS NULL THEN
        RAISE invalid_password USING message = 'invalid user or password';
      END IF;

      RETURN result;
    END;
  $$ language plpgsql;

  CREATE OR REPLACE FUNCTION auth.confirm(token UUID) RETURNS VOID AS $$
    UPDATE auth.users
      SET confirmation_token=NULL,
        confirmed_at=CURRENT_TIMESTAMP
      WHERE users.confirmation_token = confirm.token::TEXT
    ;
  $$ LANGUAGE SQL;

COMMIT;
