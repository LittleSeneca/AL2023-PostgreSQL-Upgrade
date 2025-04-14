#!/bin/bash
set -eo pipefail

# Record start time
START_TIME=$(date +%s)
START_TIME_HUMAN=$(date)
echo "Starting PostgreSQL upgrade process at: $START_TIME_HUMAN"

# Fix permissions on data directories
if [ "$(id -u)" = "0" ]; then
    echo "Setting correct permissions on data directories..."
    chown -R postgres:postgres /var/lib/pgsql/15/data
    chown -R postgres:postgres /var/lib/pgsql/16/data
    chown -R postgres:postgres /var/lib/pgsql/17/data
    chown -R postgres:postgres /var/lib/pgsql/data
    chmod 700 /var/lib/pgsql/15/data
    chmod 700 /var/lib/pgsql/16/data
    chmod 700 /var/lib/pgsql/17/data
    chmod 700 /var/lib/pgsql/data
    
    echo "Switching to postgres user..."
    exec su postgres -c "$0"
    exit 0
fi

# Handle the postgres data directory path compatibility
echo "Setting up data directory path compatibility..."
# Create symbolic link from /var/lib/pgsql/data to /var/lib/pgsql/15/data
if [ -d "/var/lib/pgsql/15/data" ] && [ "$(ls -A /var/lib/pgsql/15/data)" ]; then
    echo "Creating symbolic link from /var/lib/pgsql/data to /var/lib/pgsql/15/data..."
    # Remove the data directory if it exists but is empty
    rmdir /var/lib/pgsql/data 2>/dev/null || true
    # Create the symbolic link
    ln -sfn /var/lib/pgsql/15/data /var/lib/pgsql/data
fi

# Check if PostgreSQL 15 data directory is mounted and contains files
if [ -z "$(ls -A /var/lib/pgsql/15/data)" ]; then
    echo "Error: PostgreSQL 15 data directory is empty. Please mount your PostgreSQL 15 data to /var/lib/pgsql/15/data"
    exit 1
fi

# Record time before first upgrade
UPGRADE1_START=$(date +%s)
echo "Starting upgrade from PostgreSQL 15 to 16 at $(date)..."
/scripts/pgsql_15_to_16.sh
UPGRADE1_END=$(date +%s)
UPGRADE1_DURATION=$((UPGRADE1_END - UPGRADE1_START))
echo "Upgrade from PostgreSQL 15 to 16 completed in $(date -u -d @${UPGRADE1_DURATION} +"%H:%M:%S")."

# Record time before second upgrade
UPGRADE2_START=$(date +%s)
echo "Starting upgrade from PostgreSQL 16 to 17 at $(date)..."
/scripts/pgsql_16_to_17.sh
UPGRADE2_END=$(date +%s)
UPGRADE2_DURATION=$((UPGRADE2_END - UPGRADE2_START))
echo "Upgrade from PostgreSQL 16 to 17 completed in $(date -u -d @${UPGRADE2_DURATION} +"%H:%M:%S")."

# Run verification query
echo "Running verification query on the upgraded database at $(date)..."
/scripts/pgsql_17_query.sh
echo "Verification query completed."

# Record end time and calculate total duration
END_TIME=$(date +%s)
END_TIME_HUMAN=$(date)
TOTAL_DURATION=$((END_TIME - START_TIME))

echo "PostgreSQL upgrade process completed successfully."
echo "Your PostgreSQL 17 data is available in /var/lib/pgsql/17/data"

# Display timing summary
echo ""
echo "=== Upgrade Timing Summary ==="
echo "Started at: $START_TIME_HUMAN"
echo "Finished at: $END_TIME_HUMAN"
echo "PostgreSQL 15 to 16 upgrade: $(date -u -d @${UPGRADE1_DURATION} +"%H:%M:%S")"
echo "PostgreSQL 16 to 17 upgrade: $(date -u -d @${UPGRADE2_DURATION} +"%H:%M:%S")"
echo "Total upgrade duration: $(date -u -d @${TOTAL_DURATION} +"%H:%M:%S")"
echo "============================"

# Keep container running if specified
if [ "$1" = "keep-running" ]; then
    echo "Container will remain running. Use Ctrl+C to stop."
    tail -f /dev/null
fi
