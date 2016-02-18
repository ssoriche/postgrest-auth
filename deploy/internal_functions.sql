-- Deploy postgrest-auth:auth_functions to pg
-- requires: users_base_view

BEGIN;
  SET client_min_messages TO WARNING;

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

        IF EXISTS (SELECT 1 FROM auth.users WHERE username = new.username) THEN
          RAISE foreign_key_violation USING message = 'Invalid user name: ' || new.username;
        END IF;

        IF EXISTS (SELECT 1 FROM auth.users WHERE email = new.email) THEN
          RAISE foreign_key_violation USING message = 'Invalid email address: ' || new.email;
        END IF;

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

        IF EXISTS ( SELECT 1 FROM json_each_text(to_json(new_record)) AS X WHERE key = 'confirmation_token') THEN
          new_record.confirmation_token = uuid_generate_v4();
          new_record.confirmation_sent_at = CURRENT_TIMESTAMP;

          PERFORM pg_notify('validate',
            json_build_object(
              'email', new_record.email,
              'token', new_record.confirmation_token,
              'token_type', 'validation'
            )::text
          );

        END IF;

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
      IF new.sign_in_count != old.sign_in_count OR (new.sign_in_count IS NOT NULL AND old.sign_in_count IS NULL) THEN
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
      auth.user_role(identifier text, pass text) RETURNS name AS $$
    BEGIN
      RETURN (
      SELECT role FROM auth.users
       WHERE user_role.identifier IN (users.username, users.email)
         AND users.pass = crypt(user_role.pass, users.pass)
      );
    END;
  $$ LANGUAGE plpgsql;

  DROP TYPE IF EXISTS auth.jwt_claims CASCADE;
  CREATE TYPE auth.jwt_claims AS (role TEXT, user_id INTEGER, username TEXT, email TEXT, exp BIGINT);

COMMIT;
