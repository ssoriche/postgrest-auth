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

  DROP TRIGGER IF EXISTS users_add_trigger on auth.users;
  CREATE TRIGGER users_add_trigger
    INSTEAD OF INSERT ON
      auth.users FOR EACH ROW EXECUTE PROCEDURE auth.users_add()
  ;

  CREATE OR REPLACE FUNCTION auth.users_change() RETURNS trigger AS $auth_users_change$
    DECLARE
      inputstring TEXT;
      new_record RECORD;
      ret RECORD;
    BEGIN
      IF tg_op = 'UPDATE' or new.pass <> old.pass THEN
        IF new.reset_password_token != old.reset_password_token THEN
          new.reset_password_sent_at = CURRENT_TIMESTAMP;
        END IF;
        IF new.confirmation_token != old.confirmation_token THEN
          new.confirmation_sent_at = CURRENT_TIMESTAMP;
        END IF;
      END IF;

    END;
  $auth_users_change$ LANGUAGE plpgsql;

  DROP TRIGGER IF EXISTS auth_users_change ON auth.users_attributes_base;
  CREATE CONSTRAINT TRIGGER auth_users_change
    BEFORE DELETE or UPDATE on auth.users_attributes_base
    FOR EACH ROW
    EXECUTE PROCEDURE auth.users_change()
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

COMMIT;
