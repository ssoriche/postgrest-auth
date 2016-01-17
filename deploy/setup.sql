-- Deploy postgrest-auth:setup to pg

BEGIN;

  CREATE EXTENSION IF NOT EXISTS pgcrypto;

COMMIT;
