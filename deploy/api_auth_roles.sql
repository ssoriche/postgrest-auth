-- Deploy postgrest-auth:api_auth_roles to pg

BEGIN;

  DO
  $body$
    BEGIN
      IF NOT EXISTS (
        SELECT *
          FROM pg_catalog.pg_roles
          WHERE rolname = 'anon'
      ) THEN
        CREATE ROLE anon;
     END IF;
  END
  $body$;

  DO
  $body$
    BEGIN
      IF NOT EXISTS (
        SELECT *
          FROM pg_catalog.pg_roles
          WHERE rolname = 'authenticator'
      ) THEN
        CREATE ROLE authenticator noinherit;
     END IF;
  END
  $body$;

  GRANT ANON to authenticator;

  GRANT USAGE ON SCHEMA public, auth TO anon;

-- anon can create new logins
  GRANT INSERT ON TABLE auth.users to anon;
  GRANT SELECT ON TABLE pg_authid, auth.users to anon;
  GRANT EXECUTE ON FUNCTION
      request_password_reset(TEXT),
      reset_password(TEXT, UUID, TEXT),
      signup(TEXT, TEXT),
      confirm(UUID),
      login(TEXT, TEXT)
    TO anon
  ;

COMMIT;
