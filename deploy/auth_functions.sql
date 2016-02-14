-- Deploy postgrest-auth:auth_functions to pg
-- requires: users_base_view

BEGIN;

  CREATE OR REPLACE FUNCTION auth.check_role_exists() RETURNS trigger
    language plpgsql
    as $$
  BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles AS r WHERE r.rolname = new.role) THEN
      raise foreign_key_violation using message =
        'unknown database role: ' || new.role;
      RETURN null;
    END IF;
    RETURN new;
  END
  $$;

  DROP TRIGGER IF EXISTS ensure_user_role_exists ON auth.user_roles;
  CREATE CONSTRAINT TRIGGER ensure_user_role_exists
    AFTER INSERT or UPDATE on auth.user_roles
    for each row
    execute procedure auth.check_role_exists()
  ;

  CREATE OR REPLACE FUNCTION auth.check_user_exists() RETURNS trigger
    language plpgsql
    as $$
  BEGIN
    IF NOT EXISTS (SELECT 1 FROM auth.users AS r WHERE r.id = new.user_id) THEN
      raise foreign_key_violation using message =
        'unknown user: ' || new.user_id;
      RETURN null;
    END IF;
    RETURN new;
  END
  $$;

  DROP TRIGGER IF EXISTS ensure_user_user_exists ON auth.user_roles;
  CREATE CONSTRAINT TRIGGER ensure_user_user_exists
    AFTER INSERT or UPDATE on auth.user_roles
    for each row
    execute procedure auth.check_user_exists()
  ;

  CREATE OR REPLACE FUNCTION auth.users_add() RETURNS trigger AS $auth_users_add$
    DECLARE
      inputstring TEXT;
      new_record RECORD;
      ret RECORD;
    BEGIN
      IF tg_op = 'INSERT' THEN
        new.pass = crypt(new.pass, gen_salt('bf'));
        new.created_at = CURRENT_TIMESTAMP;
        new.updated_at = CURRENT_TIMESTAMP;

        new_record = json_populate_record(
            null::auth.users_attributes_base, to_json(NEW)
          )
        ;

        SELECT string_agg(quote_ident(key),',') INTO inputstring
          FROM json_object_keys(to_json(new_record)) AS X (key)
        ;

        EXECUTE 'INSERT INTO auth.users_base '
          || '(' || inputstring || ') SELECT ' ||  inputstring
          || ' FROM json_populate_record( NULL::auth.users_attributes_base, to_json($1)) RETURNING *'
          INTO ret USING new_record
        ;

        INSERT INTO auth.user_roles (user_id, role)
          VALUES (ret.ID, NEW.role)
        ;
      END IF;

      RETURN NEW;
    END;
  $auth_users_add$ LANGUAGE plpgsql;

  DROP TRIGGER IF EXISTS auth_users_add on auth.users;
  CREATE TRIGGER auth_users_add
    INSTEAD OF INSERT ON
      auth.users FOR EACH ROW EXECUTE PROCEDURE auth.users_add()
  ;

  CREATE OR REPLACE FUNCTION auth.users_change() RETURNS trigger AS $auth_users_change$
    DECLARE
      updatestring TEXT;
      new_record RECORD;
      ret RECORD;
    BEGIN
      IF new.username != old.username THEN
        IF EXISTS (SELECT 1 FROM auth.users WHERE username = new.username) THEN
          RAISE foreign_key_violation USING message = 'Invalid user name: ' || new.username;
        END IF;
      END IF;

      IF new.email != old.email THEN
        IF EXISTS (SELECT 1 FROM auth.users WHERE email = new.email) THEN
          RAISE foreign_key_violation USING message = 'Invalid email address: ' || new.email;
        END IF;
      END IF;

      IF new.reset_password_token != old.reset_password_token
        OR new.reset_password_token IS NOT NULL and old.reset_password_token IS NULL
      THEN
        new.reset_password_sent_at = CURRENT_TIMESTAMP;
      END IF;
      IF new.confirmation_token != old.confirmation_token THEN
        new.confirmation_sent_at = CURRENT_TIMESTAMP;
      END IF;
      IF new.sign_in_count != old.sign_in_count THEN
        new.last_sign_in_at = old.current_sign_in_at;
        new.last_sign_in_ip = old.current_sign_in_ip;
        new.current_sign_in_at = CURRENT_TIMESTAMP;
      END IF;
      IF new.pass != old.pass THEN
        new.pass = crypt(new.pass, gen_salt('bf'));
      END IF;

      new.updated_at = CURRENT_TIMESTAMP;

      new_record = json_populate_record(
          null::auth.users_attributes_base, to_json(NEW)
        )
      ;

      SELECT string_agg(quote_ident(key) || ' = ' || quote_nullable(value),',') INTO updatestring
        FROM json_each_text(to_json(new_record)) AS X
      ;

      EXECUTE 'UPDATE auth.users_base '
        || 'SET ' || updatestring
        || 'WHERE id = $1'
        USING OLD.id
      ;

      RETURN NEW;

    END;
  $auth_users_change$ LANGUAGE plpgsql;

  DROP TRIGGER IF EXISTS auth_users_change ON auth.users;
  CREATE TRIGGER auth_users_change
    INSTEAD OF UPDATE ON auth.users
    FOR EACH ROW EXECUTE PROCEDURE auth.users_change()
  ;

  CREATE OR REPLACE FUNCTION
      auth.user_role(username text, pass text) RETURNS name AS $$
    BEGIN
      RETURN (
      SELECT role FROM auth.users
       WHERE users.username = user_role.username
         AND users.pass = crypt(user_role.pass, users.pass)
      );
    END;
  $$ LANGUAGE plpgsql;

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

COMMIT;
