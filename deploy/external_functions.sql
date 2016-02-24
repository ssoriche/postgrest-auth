-- Deploy postgrest-auth:external_functions to pg
-- requires: internal_functions

BEGIN;
  SET client_min_messages TO WARNING;

  CREATE OR REPLACE FUNCTION auth.request_password_reset(identifier TEXT) RETURNS VOID AS $$
    BEGIN
      UPDATE auth.users
        SET reset_password_token = gen_random_uuid()
        WHERE request_password_reset.identifier IN (username, email)
      ;

      PERFORM pg_notify('reset',
            json_build_object(
              'email', email,
              'token', reset_password_token,
              'token_type', 'reset'
            )::text
          )
        FROM auth.users_attributes_base
        WHERE request_password_reset.identifier IN (username, email)
      ;
    END;
  $$ LANGUAGE plpgsql;

  CREATE OR REPLACE FUNCTION auth.reset_password(identifier TEXT, token UUID, pass TEXT) RETURNS VOID AS $$
    BEGIN
      IF EXISTS(
        SELECT 1 from auth.users
        WHERE reset_password.identifier IN (username, email)
          AND reset_password_token::UUID = reset_password.token
      ) THEN
        UPDATE auth.users
          SET pass = reset_password.pass,
            reset_password_token = NULL,
            reset_password_sent_at = NULL
          WHERE reset_password.identifier IN (username, email)
            AND reset_password_token::UUID = reset_password.token
        ;
      ELSE
        RAISE invalid_password USING message = 'invalid user or token';
      END IF;
    END;
  $$ LANGUAGE plpgsql;

  CREATE OR REPLACE FUNCTION auth.signup(username TEXT, email TEXT, pass TEXT, role TEXT) RETURNS VOID AS $$
    INSERT INTO auth.users (username, email, pass, role) VALUES (signup.username, signup.email, signup.pass, signup.role);
  $$ LANGUAGE SQL;

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

      UPDATE auth.users
        SET sign_in_count = COALESCE(sign_in_count,0) + 1
        WHERE users.id = result.user_id
      ;

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

  CREATE OR REPLACE FUNCTION auth.change_password(identifier TEXT, current_password TEXT, new_password TEXT, confirm_password TEXT) RETURNS void AS $$
    BEGIN
      IF EXISTS(
        SELECT 1 from auth.users
        WHERE change_password.identifier IN (username, email)
          AND users.pass = crypt(change_password.current_password, users.pass)
          AND change_password.new_password = change_password.confirm_password
      ) THEN
        UPDATE auth.users
          SET pass = change_password.new_password
          WHERE change_password.identifier IN (username, email)
            AND users.pass = crypt(change_password.current_password, users.pass)
            AND change_password.new_password = change_password.confirm_password
        ;
      ELSE
        RAISE invalid_password USING message = 'invalid password';
      END IF;
    END;
  $$ language plpgsql;

COMMIT;
