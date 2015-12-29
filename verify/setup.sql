-- Verify postgrest-auth:setup on pg

BEGIN;

  SELECT 1/count(*) FROM pg_extension WHERE extname = 'pgcrypto';
  SELECT has_function_privilege('crypt(text,text)', 'execute');


  SELECT 1/count(*) FROM pg_extension WHERE extname = 'uuid-ossp';
  SELECT has_function_privilege('uuid_generate_v4()', 'execute');

ROLLBACK;
