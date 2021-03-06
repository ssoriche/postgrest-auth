-- Deploy postgrest-auth:auth_functions to pg
-- requires: users_base_view

BEGIN;
  SET client_min_messages TO WARNING;

  CREATE OR REPLACE FUNCTION auth.clearance_for_role(u name) RETURNS VOID AS $$
    DECLARE
      ok BOOLEAN;
    BEGIN
      SELECT EXISTS (
        SELECT rolname
          FROM pg_authid
          WHERE pg_has_role(current_user, oid, 'member')
            AND rolname = u
        ) INTO ok
      ;

      IF NOT ok THEN
        RAISE invalid_password
          USING message = 'current user not member of role ' || u
        ;
      END IF;
    END;
  $$ LANGUAGE plpgsql;

  CREATE OR REPLACE FUNCTION auth.check_role_exists() RETURNS trigger
    language plpgsql
    as $$
  BEGIN
    IF NOT auth.check_role_exists(new.role) THEN
      raise foreign_key_violation using message =
        'unknown database role: ' || new.role;
      RETURN null;
    END IF;
    RETURN new;
  END;
  $$;

  CREATE OR REPLACE FUNCTION auth.check_role_exists(role TEXT) RETURNS BOOLEAN
    language plpgsql
    as $$
  BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles AS r WHERE r.rolname = check_role_exists.role) THEN
      raise foreign_key_violation using message =
        'unknown database role: ' || check_role_exists.role;
      RETURN FALSE;
    END IF;
    RETURN TRUE;
  END;
  $$;

  DO
  $body$
    BEGIN
      IF EXISTS (
        SELECT *
          FROM pg_catalog.pg_tables
          WHERE schemaname = 'auth'
            AND tablename = 'user_roles'
      ) THEN
        DROP TRIGGER IF EXISTS ensure_user_role_exists ON auth.user_roles;
        CREATE CONSTRAINT TRIGGER ensure_user_role_exists
          AFTER INSERT or UPDATE on auth.user_roles
          for each row
          execute procedure auth.check_role_exists()
        ;
     END IF;
  END
  $body$;

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
  END;
  $$;

  DO
  $body$
    BEGIN
      IF EXISTS (
        SELECT *
          FROM pg_catalog.pg_tables
          WHERE schemaname = 'auth'
            AND tablename = 'user_roles'
      ) THEN
        DROP TRIGGER IF EXISTS ensure_user_user_exists ON auth.user_roles;
        CREATE CONSTRAINT TRIGGER ensure_user_user_exists
          AFTER INSERT or UPDATE on auth.user_roles
          for each row
          execute procedure auth.check_user_exists()
        ;
     END IF;
  END
  $body$;

  CREATE OR REPLACE FUNCTION auth.record_key_exists(JSON,TEXT) RETURNS BOOLEAN AS $$
    DECLARE
      ret BOOLEAN;
    BEGIN
      SELECT EXISTS ( SELECT 1 FROM json_each_text($1) AS X WHERE key = $2::TEXT) INTO ret;
      RETURN ret;
    END;
  $$ LANGUAGE plpgsql;

  CREATE OR REPLACE FUNCTION auth.users_add() RETURNS trigger AS $auth_users_add$
    DECLARE
      inputstring TEXT;
      new_record RECORD;
      ret RECORD;
    BEGIN
      IF tg_op = 'INSERT' THEN

        new_record = json_populate_record(
            null::auth.users_attributes_base, to_json(NEW)
          )
        ;

        IF auth.record_key_exists(to_json(new_record), 'username')
            AND EXISTS (SELECT 1 FROM auth.users WHERE username = new.username)
        THEN
          RAISE foreign_key_violation USING message = 'Invalid user name: ' || new.username;
        END IF;


        IF auth.record_key_exists(to_json(new_record), 'email')
            AND EXISTS (SELECT 1 FROM auth.users WHERE email = new.email)
        THEN
          RAISE foreign_key_violation USING message = 'Invalid email address: ' || new.email;
        END IF;

        PERFORM auth.clearance_for_role(new.role);

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
          new_record.confirmation_token = gen_random_uuid();
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

        IF NOT auth.record_key_exists(to_json(new_record), 'role') THEN
          INSERT INTO auth.user_roles (user_id, role)
            VALUES (ret.ID, NEW.role)
          ;
        ELSE
        END IF;
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
        IF auth.record_key_exists(to_json(new),'last_sign_in_at') AND auth.record_key_exists(to_json(old),'current_sign_in_at') THEN
          new.last_sign_in_at = old.current_sign_in_at;
        END IF;
        IF auth.record_key_exists(to_json(new),'last_sign_in_ip') AND auth.record_key_exists(to_json(old),'current_sign_in_ip') THEN
          new.last_sign_in_ip = old.current_sign_in_ip;
        END IF;
        new.current_sign_in_at = CURRENT_TIMESTAMP;
      END IF;
      IF new.pass != old.pass THEN
        new.pass = crypt(new.pass, gen_salt('bf'));
      END IF;
      IF new.role != old.role THEN
        PERFORM auth.clearance_for_role(new.role);
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

      IF NOT EXISTS (
        SELECT 1
          FROM json_object_keys(to_json(new_record)) AS X (key)
          WHERE key = 'role'
      ) THEN
        IF NEW.role <> OLD.role THEN
          UPDATE auth.user_roles
            SET role = NEW.role
            WHERE user_id = OLD.id
          ;
        END IF;
      END IF;

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

  CREATE OR REPLACE FUNCTION auth.update_sign_in_attributes(user_id INTEGER) RETURNS void AS $$
    DECLARE
      updatecolumns TEXT[] DEFAULT '{}';
    BEGIN
      IF EXISTS (SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'auth'
          AND table_name = 'users'
          AND column_name = 'sign_in_count'
      ) THEN
        updatecolumns := updatecolumns || 'sign_in_count = COALESCE(sign_in_count,0) + 1'::TEXT;

      END IF;

      IF EXISTS (SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'auth'
          AND table_name = 'users'
          AND column_name = 'current_sign_in_at'
      ) THEN
        updatecolumns := updatecolumns || 'current_sign_in_at = CURRENT_TIMESTAMP'::TEXT;
      END IF;

      IF array_length(updatecolumns,1) > 0 THEN
        EXECUTE 'UPDATE auth.users SET ' ||  array_to_string(updatecolumns,', ')
          || ' WHERE id = $1' USING update_sign_in_attributes.user_id
        ;
      END IF;
    END;
  $$ LANGUAGE plpgsql;

COMMIT;
