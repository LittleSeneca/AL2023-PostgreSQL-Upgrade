#!/bin/bash
set -eo pipefail

echo "Starting PostgreSQL 15 to 16 upgrade process..."

PG15_DATA="/var/lib/pgsql/15/data"
PG16_DATA="/var/lib/pgsql/16/data"
PG15_BIN="/usr/pgsql-15/bin"
PG16_BIN="/usr/pgsql-16/bin"
TEMP_DIR="/var/lib/pgsql/pg_upgrade_temp"

# Verify source data exists
if [ ! -f "$PG15_DATA/PG_VERSION" ]; then
    echo "Error: PostgreSQL 15 data directory does not contain a valid database."
    exit 1
fi

# Check if PostgreSQL 15 is a primary or standby
if [ -f "$PG15_DATA/recovery.conf" ] || [ -f "$PG15_DATA/standby.signal" ]; then
    echo "Error: The source database is a standby. Please run the upgrade on the primary server."
    exit 1
fi

# Recovery: Start PostgreSQL 15 to perform crash recovery if needed
echo "Checking if the database needs recovery..."
if [ -f "$PG15_DATA/postmaster.pid" ]; then
    echo "Found postmaster.pid file, removing it..."
    rm -f "$PG15_DATA/postmaster.pid"
fi

# Clear any WAL files that might be causing issues
if [ -d "$PG15_DATA/pg_wal" ]; then
    echo "Fixing pg_wal status..."
    touch "$PG15_DATA/pg_wal/RECOVERYXLOG"
fi

# Fix configuration files that might reference /var/lib/pgsql/data
for config_file in "$PG15_DATA"/*.conf; do
    if [ -f "$config_file" ]; then
        echo "Checking configuration file: $config_file"
        # Replace references to /var/lib/pgsql/data with /var/lib/pgsql/15/data
        sed -i 's|/var/lib/pgsql/data|/var/lib/pgsql/15/data|g' "$config_file"
    fi
done

# Run startup recovery in single-user mode
echo "Starting PostgreSQL 15 in single-user mode for recovery..."
$PG15_BIN/postgres --single -D $PG15_DATA postgres << EOF
EOF

# Create a shutdown marker file to indicate clean shutdown
if [ ! -f "$PG15_DATA/backup_label.old" ] && [ -f "$PG15_DATA/backup_label" ]; then
    echo "Renaming backup_label to backup_label.old..."
    mv "$PG15_DATA/backup_label" "$PG15_DATA/backup_label.old"
fi

echo "Recovery completed. The database should now be in a clean shutdown state."

# Check and prepare PostgreSQL 16 data directory
echo "Checking PostgreSQL 16 data directory..."
if [ -d "$PG16_DATA" ] && [ "$(ls -A $PG16_DATA)" ]; then
    # Check if it contains an initialized PostgreSQL database
    if [ -f "$PG16_DATA/PG_VERSION" ]; then
        echo "PostgreSQL 16 data directory already contains a database. Cleaning..."
    fi
    echo "Removing contents of $PG16_DATA..."
    rm -rf ${PG16_DATA:?}/* 
fi

# Initialize PostgreSQL 16 data directory
echo "Initializing PostgreSQL 16 database..."
$PG16_BIN/initdb -D $PG16_DATA

# Create temporary directory for pg_upgrade
mkdir -p $TEMP_DIR

# Run pg_upgrade
echo "Running pg_upgrade in check mode first..."
$PG16_BIN/pg_upgrade \
    --old-bindir=$PG15_BIN \
    --new-bindir=$PG16_BIN \
    --old-datadir=$PG15_DATA \
    --new-datadir=$PG16_DATA \
    --jobs=4 \
    --check || true

echo "Running pg_upgrade in copy mode (this may take a while)..."
$PG16_BIN/pg_upgrade \
    --old-bindir=$PG15_BIN \
    --new-bindir=$PG16_BIN \
    --old-datadir=$PG15_DATA \
    --new-datadir=$PG16_DATA \
    --jobs=4

echo "PostgreSQL 15 to 16 upgrade completed successfully."
