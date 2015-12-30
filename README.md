PostgREST Authentication Example/Starting Point
===============================================

This application can be used as a starting point for PostgREST authentication
based on a [Devise](https://github.com/plataformatec/devise) installation.

Database setup, management, and configuration is done via
[sqitch](http://sqitch.org). One of the components of the installation creates
a Devise based Users table, simply comment out the contents of
deploy/devise_test.sql and update the users_view.sql to point at the
appropriate table.
