#!/bin/sh
PSQL_SELECT='psql -t -A -U gis -c'
PSQL_COMMAND='psql -q -U gis -c'

username=$1

if [ -z "${username}" ]; then
  printf 'Enter username: '
  read -r username
  echo
fi

if [ -z "${username}" ]; then
  echo "Empty string is not a valid username"
  exit 1
fi

if [ -z "$(${PSQL_SELECT} "SELECT to_regrole('geocint_users');")" ]; then
  echo "Create group role geocint_users"
  ${PSQL_COMMAND} "
    CREATE ROLE geocint_users;
    GRANT pg_monitor TO geocint_users;
    GRANT pg_signal_backend TO geocint_users;
  "
fi

if [ -z "$(${PSQL_SELECT} "SELECT to_regrole('${username}');")" ]; then
  echo "Create login role ${username}"
  ${PSQL_COMMAND} "
    CREATE ROLE ${username} LOGIN;
    GRANT geocint_users TO ${username};
  "
fi

if [ -z "$(${PSQL_SELECT} "SELECT to_regnamespace('${username}');")" ]; then
  echo "Creating user schema ${username}"
  ${PSQL_COMMAND} "
    CREATE SCHEMA AUTHORIZATION ${username};
  "
fi
