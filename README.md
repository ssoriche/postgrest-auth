PostgREST Authentication Example/Starting Point
===============================================

This application can be used as a starting point for PostgREST authentication
based on a [Devise](https://github.com/plataformatec/devise) installation.

Database setup, management, and configuration is done via
[sqitch](http://sqitch.org). One of the components of the installation creates
a Devise based Users table, simply comment out the contents of
deploy/devise_test.sql and update the users_view.sql to point at the
appropriate table.

Functions
---------

- auth.request_password_reset(identifier TEXT)
- auth.reset_password(identifier TEXT, token UUID, pass TEXT)
- auth.signup(username TEXT, email TEXT, pass TEXT, role TEXT)
- auth.confirm(token UUID, role TEXT)
- auth.login(identifier TEXT, pass TEXT, exp INTEGER=NULL)
- auth.change_password(identifier TEXT, current_password TEXT, new_password TEXT, confirm_password TEXT)
