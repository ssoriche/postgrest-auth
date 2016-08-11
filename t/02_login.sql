BEGIN;

  SELECT plan( 6 );

  SET ROLE anon;

  SELECT lives_ok(
    'SELECT "public".signup(''ssoriche'', ''shawn@coloredblocks.com'', ''Ch4ng3m3'')',
    'Execute the signup process'
  );

  SELECT lives_ok(
    'SELECT "public". confirm(confirmation_token::UUID) FROM auth.users WHERE username = ''ssoriche''',
    'Execute the confirmation process'
  );

  SELECT lives_ok(
    'SELECT "public".login(''ssoriche'', ''Ch4ng3m3'')',
    'Execute the login process'
  );

  SELECT lives_ok(
    'SELECT "public".signup(''linda@coloredblocks.com'', ''Ch4ng3m3'')',
    'Execute the signup process'
  );

  SELECT lives_ok(
    'SELECT "public". confirm(confirmation_token::UUID) FROM auth.users WHERE username = ''linda@coloredblocks.com''',
    'Execute the confirmation process'
  );

  SELECT lives_ok(
    'SELECT "public".login(''linda@coloredblocks.com'', ''Ch4ng3m3'')',
    'Execute the login process'
  );

  SELECT * FROM finish();
ROLLBACK;
