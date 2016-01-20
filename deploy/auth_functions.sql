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

  CREATE OR REPLACE FUNCTION auth.users_change() RETURNS trigger AS $auth_users$
    DECLARE
      inputstring TEXT;
      new_record RECORD;
      ret RECORD;
    BEGIN        
      IF tg_op = 'INSERT' or new.pass <> old.pass THEN
        new.pass = crypt(new.pass, gen_salt('bf'));
      END IF;

      IF tg_op = 'INSERT' THEN
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
  $auth_users$ LANGUAGE plpgsql;

  DROP TRIGGER IF EXISTS users_trigger on auth.users;
  CREATE TRIGGER users_trigger
    INSTEAD OF INSERT OR UPDATE OR DELETE ON
      auth.users FOR EACH ROW EXECUTE PROCEDURE auth.users_change()
  ;

COMMIT;
