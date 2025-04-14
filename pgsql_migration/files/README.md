# PostgreSQL Migration Container

This container helps you upgrade a PostgreSQL 15 database to PostgreSQL 17 in two steps:
1. Upgrade from PostgreSQL 15 to 16
2. Upgrade from PostgreSQL 16 to 17

## Prerequisites

- Docker and Docker Compose installed
- AWS CLI installed (if downloading from S3)
- A PostgreSQL 15 database backup or data directory

## Quick Start

1. **Prepare your PostgreSQL 15 data**

   You can use the provided script to download and prepare data from an S3 backup:

   ```bash
   ./source_backup.sh
   ```

   Alternatively, you can manually place your PostgreSQL 15 data files in a directory (e.g., `./pg15_data`).

2. **Run the migration**

   ```bash
   docker-compose up --build
   ```

   This will:
   - Build the container with PostgreSQL 15, 16, and 17 installed
   - Mount your PostgreSQL 15 data directory
   - Run the upgrade from PostgreSQL 15 to 16
   - Run the upgrade from PostgreSQL 16 to 17
   - Output the PostgreSQL 17 data to the specified directory

3. **Access your upgraded PostgreSQL 17 data**

   After the migration completes, your PostgreSQL 17 data will be available in the directory specified by `PG17_OUTPUT_PATH` (default: `./pg17_data`).

## Configuration Options

You can customize the migration process using the following environment variables:

- `PG15_DATA_PATH`: Path to your PostgreSQL 15 data directory (default: `./pg15_data`)
- `PG17_OUTPUT_PATH`: Path where the PostgreSQL 17 data will be stored (default: `./pg17_data`)
- `UPGRADE_JOBS`: Number of parallel jobs to use for the upgrade process (default: 4)

## Troubleshooting

- **Check the logs**: If the migration fails, check the container logs for error messages.
- **Valid PostgreSQL 15 data**: Ensure your PostgreSQL 15 data directory contains valid database files.
- **Permissions**: Make sure the mounted directories have the correct permissions.

## Notes

- The upgrade uses the `--link` option for efficiency, which creates hard links instead of copying files.
- The container will keep running after the upgrade if you use the `keep-running` command (default in docker-compose.yml).
- You can remove the `command: keep-running` line from docker-compose.yml if you want the container to exit after the upgrade. 