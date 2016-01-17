-- Verify postgrest-auth:setup on pg

BEGIN;

  SELECT 1/count(*) FROM pg_extension WHERE extname = 'pgcrypto';
  SELECT has_function_privilege('crypt(text,text)', 'execute');
  SELECT has_function_privilege('gen_random_uuid()', 'execute');

ROLLBACK;
