#!/bin/sh
set -e

if [ -n "${DATABASE_HOST}" ]; then
  echo "Waiting for PostgreSQL at ${DATABASE_HOST}:${DATABASE_PORT:-5432}..."
  python - <<'PY'
import os
import socket
import sys
import time

host = os.environ["DATABASE_HOST"]
port = int(os.environ.get("DATABASE_PORT", "5432"))

for attempt in range(60):
    try:
        with socket.create_connection((host, port), timeout=2):
            print("PostgreSQL is available.")
            break
    except OSError:
        time.sleep(1)
else:
    sys.exit("PostgreSQL did not become available in time.")
PY
fi

python manage.py migrate --noinput
python manage.py collectstatic --noinput
exec "$@"
