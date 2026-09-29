#!/bin/sh
set -eu

# Runs only when the PostgreSQL volume is empty. Rails never uses a superuser.
export PSYCHOLOGIST_APP_PASSWORD="$(cat /run/secrets/db_password)"
psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" --set ON_ERROR_STOP=1 <<'SQL'
\getenv app_password PSYCHOLOGIST_APP_PASSWORD
CREATE ROLE psychologist LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE PASSWORD :'app_password';
ALTER DATABASE psychologist_production OWNER TO psychologist;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT ALL ON SCHEMA public TO psychologist;
SQL
unset PSYCHOLOGIST_APP_PASSWORD
