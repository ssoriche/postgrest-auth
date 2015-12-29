-- Deploy postgrest-auth:setup to pg

BEGIN;

  CREATE EXTENSION IF NOT EXISTS pgcrypto;
  CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

COMMIT;
