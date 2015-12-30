-- Deploy postgrest-auth:auth_schema to pg

BEGIN;

  CREATE SCHEMA IF NOT EXISTS auth;

COMMIT;
