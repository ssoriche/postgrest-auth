-- Deploy postgrest-auth:devise_test to pg

BEGIN;

  CREATE SCHEMA IF NOT EXISTS devise_test;

  CREATE TABLE IF NOT EXISTS devise_test.users (
      id serial,

      username character varying(255) DEFAULT ''::character varying NOT NULL,
      facebook_token character varying(255),

      email character varying(255) DEFAULT ''::character varying NOT NULL,
      encrypted_password character varying(255) DEFAULT ''::character varying NOT NULL,

      reset_password_token character varying(255),
      reset_password_sent_at timestamp without time zone,

      remember_created_at timestamp without time zone,

      sign_in_count integer DEFAULT 0,
      current_sign_in_at timestamp without time zone,
      last_sign_in_at timestamp without time zone,
      current_sign_in_ip character varying(255),
      last_sign_in_ip character varying(255),

      confirmation_token character varying(255),
      confirmed_at timestamp without time zone,
      confirmation_sent_at timestamp without time zone,

      failed_attempts integer DEFAULT 0,
      unlock_token character varying(255),
      locked_at timestamp without time zone,

      created_at timestamp without time zone NOT NULL,
      updated_at timestamp without time zone NOT NULL
  );

COMMIT;
