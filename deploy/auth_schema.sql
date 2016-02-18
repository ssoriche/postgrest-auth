-- Deploy postgrest-auth:auth_schema to pg

BEGIN;
  SET client_min_messages TO WARNING;

  CREATE SCHEMA IF NOT EXISTS auth;

COMMIT;
