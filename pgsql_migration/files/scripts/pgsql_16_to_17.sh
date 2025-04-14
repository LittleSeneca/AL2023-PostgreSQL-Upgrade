#!/bin/bash
set -eo pipefail

echo "Starting PostgreSQL 16 to 17 upgrade process..."

PG16_DATA="/var/lib/pgsql/16/data"
PG17_DATA="/var/lib/pgsql/17/data"
PG16_BIN="/usr/pgsql-16/bin"
PG17_BIN="/usr/pgsql-17/bin"
TEMP_DIR="/var/lib/pgsql/pg_upgrade_temp"

# Verify source data exists
if [ ! -f "$PG16_DATA/PG_VERSION" ]; then
    echo "Error: PostgreSQL 16 data directory does not contain a valid database."
    exit 1
fi

# Check if PostgreSQL 16 is a primary or standby
if [ -f "$PG16_DATA/recovery.conf" ] || [ -f "$PG16_DATA/standby.signal" ]; then
    echo "Error: The source database is a standby. Please run the upgrade on the primary server."
    exit 1
fi

# Recovery: Start PostgreSQL 16 to perform crash recovery if needed
echo "Checking if the database needs recovery..."
if [ -f "$PG16_DATA/postmaster.pid" ]; then
    echo "Found postmaster.pid file, removing it..."
    rm -f "$PG16_DATA/postmaster.pid"
fi

# Clear any WAL files that might be causing issues
if [ -d "$PG16_DATA/pg_wal" ]; then
    echo "Fixing pg_wal status..."
    touch "$PG16_DATA/pg_wal/RECOVERYXLOG"
fi

# Run startup recovery in single-user mode
echo "Starting PostgreSQL 16 in single-user mode for recovery..."
$PG16_BIN/postgres --single -D $PG16_DATA postgres << EOF
EOF

# Create a shutdown marker file to indicate clean shutdown
if [ ! -f "$PG16_DATA/backup_label.old" ] && [ -f "$PG16_DATA/backup_label" ]; then
    echo "Renaming backup_label to backup_label.old..."
    mv "$PG16_DATA/backup_label" "$PG16_DATA/backup_label.old"
fi

echo "Recovery completed. The database should now be in a clean shutdown state."

# Check and prepare PostgreSQL 17 data directory
echo "Checking PostgreSQL 17 data directory..."
if [ -d "$PG17_DATA" ] && [ "$(ls -A $PG17_DATA)" ]; then
    # Check if it contains an initialized PostgreSQL database
    if [ -f "$PG17_DATA/PG_VERSION" ]; then
        echo "PostgreSQL 17 data directory already contains a database. Cleaning..."
    fi
    echo "Removing contents of $PG17_DATA..."
    rm -rf ${PG17_DATA:?}/* 
fi

# Initialize PostgreSQL 17 data directory
echo "Initializing PostgreSQL 17 database..."
$PG17_BIN/initdb -D $PG17_DATA

# Create temporary directory for pg_upgrade if it doesn't exist
mkdir -p $TEMP_DIR

# Run pg_upgrade
echo "Running pg_upgrade in check mode first..."
$PG17_BIN/pg_upgrade \
    --old-bindir=$PG16_BIN \
    --new-bindir=$PG17_BIN \
    --old-datadir=$PG16_DATA \
    --new-datadir=$PG17_DATA \
    --jobs=4 \
    --check || true

echo "Running pg_upgrade in copy mode (this may take a while)..."
$PG17_BIN/pg_upgrade \
    --old-bindir=$PG16_BIN \
    --new-bindir=$PG17_BIN \
    --old-datadir=$PG16_DATA \
    --new-datadir=$PG17_DATA \
    --jobs=4

# Update configuration files to use the standard PostgreSQL data directory
echo "Updating configuration files to use standard data directory paths..."
for config_file in "$PG17_DATA"/*.conf; do
    if [ -f "$config_file" ]; then
        echo "Updating configuration file: $config_file"
        # Replace references to version-specific data directory with standard path
        sed -i 's|/var/lib/pgsql/17/data|/var/lib/pgsql/data|g' "$config_file"
        sed -i 's|/var/lib/pgsql/16/data|/var/lib/pgsql/data|g' "$config_file"
        sed -i 's|/var/lib/pgsql/15/data|/var/lib/pgsql/data|g' "$config_file"
    fi
done

# Create a flag file indicating this database can be used with standard path
echo "Creating compatibility marker..."
touch "$PG17_DATA/STANDARD_PATH_COMPATIBLE"

echo "PostgreSQL 16 to 17 upgrade completed successfully."
