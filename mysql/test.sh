#!/bin/sh
# Conformance test against spec/vectors.json.
# From mysql/: ./test.sh
#
# Connects with the mysql client (or mariadb, if that is the only client).
# MYSQL_HOST (default 127.0.0.1), MYSQL_PORT (default 3306), MYSQL_USER
# (default root). Set MYSQL_PWD to a password; otherwise the client is invoked
# with --skip-password.
# Installs into a scratch database named uuid58_test and drops it on success.
set -eu
cd "$(dirname "$0")"

host="${MYSQL_HOST:-127.0.0.1}"
port="${MYSQL_PORT:-3306}"
user="${MYSQL_USER:-root}"

if command -v mysql >/dev/null 2>&1; then
  client=mysql
elif command -v mariadb >/dev/null 2>&1; then
  client=mariadb
else
  echo "mysql client not found" >&2
  exit 1
fi

if [ -n "${MYSQL_PWD:-}" ]; then
  set -- --password="$MYSQL_PWD"
else
  set -- --skip-password
fi

# MariaDB's client continues after an error in a script unless told to stop.
# MySQL 8.4 already stops, and does not accept the flag.
if "$client" --help 2>&1 | grep -q -- '--abort-source-on-error'; then
  set -- "$@" --abort-source-on-error
fi

# POSIX od, so the script does not need Python. UNHEX accepts the lowercase hex.
vectors_hex=$(od -An -tx1 ../spec/vectors.json | tr -d '[:space:]')

{
  cat <<EOF
DROP DATABASE IF EXISTS uuid58_test;
CREATE DATABASE uuid58_test CHARACTER SET utf8mb4;
USE uuid58_test;
SET @vectors = CONVERT(UNHEX('${vectors_hex}') USING utf8mb4);
EOF
  # Twice, so a second install replaces the functions.
  cat uuid58.sql
  cat uuid58.sql
  cat test.sql
  echo 'DROP DATABASE uuid58_test;'
} | "$client" \
  --protocol=tcp \
  --host="$host" \
  --port="$port" \
  --user="$user" \
  "$@" \
  --default-character-set=utf8mb4 \
  --batch \
  --database=mysql
