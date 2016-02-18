-- Deploy postgrest-auth:user_roles to pg
-- requires: users_base_view
-- requires: auth_schema

BEGIN;
  SET client_min_messages TO WARNING;

  CREATE TABLE IF NOT EXISTS auth.user_roles (
    id SERIAL,
    user_id INTEGER,
    role NAME NOT NULL CHECK (length(role) < 512)
  );

COMMIT;
