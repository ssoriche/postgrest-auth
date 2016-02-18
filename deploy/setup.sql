-- Deploy postgrest-auth:setup to pg

BEGIN;
  SET client_min_messages TO WARNING;

  CREATE EXTENSION IF NOT EXISTS pgcrypto;

COMMIT;
