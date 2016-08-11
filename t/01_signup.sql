BEGIN;

  SELECT plan( 14 );

  SET ROLE anon;

  SELECT lives_ok(
    'SELECT "public".signup(''ssoriche'',''shawn@coloredblocks.com'', ''Ch4ng3m3'')',
    'Execute the signup process'
  );

  SELECT throws_ok(
    'SELECT "public".signup(''ssoriche'',''shawn@coloredblocks.com'', ''Ch4ng3m3'')',
    23503, 'Invalid user name: ssoriche',
    'Execute the signup process for existing user'
  );

  SELECT isnt(confirmation_token, NULL, 'Confirmation Token generated')
    FROM auth.users
    WHERE username = 'ssoriche'
  ;

  SELECT is(role, 'unverified', 'Confirmation Token nulled')
    FROM auth.users
    WHERE username = 'ssoriche'
  ;

  SELECT lives_ok(
    'SELECT "public". confirm(confirmation_token::UUID) FROM auth.users WHERE username = ''ssoriche''',
    'Execute the confirmation process'
  );

  SELECT is(confirmation_token, NULL, 'Confirmation Token nulled')
    FROM auth.users
    WHERE username = 'ssoriche'
  ;

  SELECT is(role, 'member', 'Confirmation Token nulled')
    FROM auth.users
    WHERE username = 'ssoriche'
  ;

  SELECT lives_ok(
    'SELECT "public".signup(''linda@coloredblocks.com'', ''Ch4ng3m3'')',
    'Execute the signup process'
  );

  SELECT throws_ok(
    'SELECT "public".signup(''linda@coloredblocks.com'', ''Ch4ng3m3'')',
    23503, 'Invalid user name: linda@coloredblocks.com',
    'Execute the signup process for existing user'
  );

  SELECT isnt(confirmation_token, NULL, 'Confirmation Token generated')
    FROM auth.users
    WHERE username = 'linda@coloredblocks.com'
  ;

  SELECT is(role, 'unverified', 'Confirmation Token nulled')
    FROM auth.users
    WHERE username = 'linda@coloredblocks.com'
  ;

  SELECT lives_ok(
    'SELECT "public". confirm(confirmation_token::UUID) FROM auth.users WHERE username = ''linda@coloredblocks.com''',
    'Execute the confirmation process'
  );

  SELECT is(confirmation_token, NULL, 'Confirmation Token nulled')
    FROM auth.users
    WHERE username = 'linda@coloredblocks.com'
  ;

  SELECT is(role, 'member', 'Confirmation Token nulled')
    FROM auth.users
    WHERE username = 'linda@coloredblocks.com'
  ;
  SELECT * FROM finish();
ROLLBACK;
