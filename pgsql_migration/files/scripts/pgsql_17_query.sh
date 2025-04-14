#!/bin/bash
set -eo pipefail

echo "Running verification query on upgraded PostgreSQL 17 database..."

# Configuration
PG17_DATA="/var/lib/pgsql/17/data"
PG17_BIN="/usr/pgsql-17/bin"
DATABASE="af30"

# Check if PostgreSQL 17 is running, if not start it temporarily
if ! $PG17_BIN/pg_ctl -D $PG17_DATA status > /dev/null 2>&1; then
    echo "Starting PostgreSQL 17 temporarily for verification..."
    $PG17_BIN/pg_ctl -D $PG17_DATA start -w
    started_pg=true
fi

# Run the query
echo "Executing verification query on database '$DATABASE'..."
$PG17_BIN/psql -d $DATABASE -c "
(
    SELECT 'personas' AS relation, id, last_login_ts
    FROM personas
    ORDER BY last_login_ts DESC NULLS LAST
    LIMIT 3
)
UNION ALL 
(
    SELECT 'records' AS relation, id, create_ts
    FROM records
    ORDER BY create_ts DESC
    LIMIT 3
);"

# If we started PostgreSQL, stop it
if [ "$started_pg" = true ]; then
    echo "Stopping temporary PostgreSQL 17 instance..."
    $PG17_BIN/pg_ctl -D $PG17_DATA stop -m fast
fi

echo "Verification query completed." 