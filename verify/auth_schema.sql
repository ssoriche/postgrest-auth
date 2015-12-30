-- Verify postgrest-auth:auth_schema on pg

BEGIN;

  SELECT pg_catalog.has_schema_privilege('auth', 'usage');
  SELECT 1/COUNT(*) FROM information_schema.schemata WHERE schema_name = 'auth';

ROLLBACK;
