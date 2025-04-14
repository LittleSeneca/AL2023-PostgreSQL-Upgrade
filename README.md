# RHEL PostgreSQL Upgrade Role

An Ansible role to upgrade PostgreSQL from version 15 to 17 on Amazon Linux 2023 instances. 

## Why This Exists

Amazon Linux does not support having multiple versions of PostgreSQL installed simultaneously on the same system. This limitation creates significant challenges when upgrading to newer PostgreSQL versions, as traditional in-place upgrade methods are not possible.

PostgreSQL 17 was only recently added to Amazon Linux 2023 repositories, creating a need for a reliable upgrade path for production servers. This role provides an automated solution that works around these limitations by:

1. Creating a temporary backup of your database data
2. Removing the old PostgreSQL installation
3. Installing the new PostgreSQL 17 packages
4. Performing the upgrade using pg_upgrade with proper safeguards

## Overview

This role automates the PostgreSQL database upgrade process by:
1. Creating an EBS volume for backup
2. Backing up the existing PostgreSQL data
3. Upgrading Amazon Linux 2023 if needed
4. Installing PostgreSQL 17 and dependencies
5. Performing the database upgrade
6. Cleaning up temporary resources after successful migration

## Prerequisites

- Ansible 2.9+
- An Amazon Linux 2023 instance running PostgreSQL 15
- IAM permissions to create/attach/delete EBS volumes
- Sufficient space for database backup (the role creates a 350GB io2 volume by default)

## Role Variables

Variables configured in `vars/main.yml`:

```yaml
postgresql_dir: "/var/lib/pgsql" # PostgreSQL installation directory
production_dir: "/var/lib/pgsql/data" # PostgreSQL data directory
backup_dir: "/mnt/backup"        # Backup directory
amazon_linux_version: "2023.7.20250331" # Target Amazon Linux version
```

## Usage

1. Add the role to your playbook:

```yaml
- hosts: postgresql_servers
  become: yes
  roles:
    - role: rhel-postgresql-upgrade
```

2. Run the playbook:

```bash
ansible-playbook -i inventory.ini upgrade_postgresql.yml
```

## Migration Process

The role performs these steps:

1. **Backup Creation**
   - Creates a new 350GB io2 EBS volume
   - Attaches and formats the volume
   - Creates a backup of the PostgreSQL data directory

2. **OS Upgrade**
   - Checks and upgrades Amazon Linux to the required version
   - Reboots if necessary

3. **PostgreSQL Installation**
   - Removes PostgreSQL 15 packages
   - Installs PostgreSQL 17 packages and dependencies
   - Installs Docker (used during upgrade process)

4. **Database Upgrade**
   - Performs the PostgreSQL upgrade using pg_upgrade
   - Validates the upgraded database

5. **Cleanup**
   - Unmounts and removes the backup volume
   - Removes temporary files and Docker installations

## Docker Component

This role uses Docker to facilitate the PostgreSQL upgrade process. Since Amazon Linux doesn't support multiple PostgreSQL versions simultaneously, a Docker container is used to perform the actual upgrade.

### How it Works

1. The role builds a Docker image using AlmaLinux 9 as the base
2. Inside the container, PostgreSQL versions 15, 16, and 17 are installed
3. Your PostgreSQL 15 data is mounted into the container
4. The upgrade process uses pg_upgrade to first upgrade from 15 to 16, then from 16 to 17
5. The upgraded data directory is then copied back to your host system

### Customizing the PostgreSQL Versions

If you need to modify the source or target PostgreSQL version:

1. **Dockerfile Modifications**:
   - Edit `pgsql_migration/files/Dockerfile` to add or remove PostgreSQL versions
   - For example, to upgrade from PostgreSQL 14, add `postgresql14-server postgresql14-contrib` to the installation list
   - Make sure to create the appropriate data directories for any new versions

2. **Script Modifications**:
   - The upgrade scripts are located in `pgsql_migration/files/scripts/`:
     - `pgsql_15_to_16.sh`: Handles upgrade from PostgreSQL 15 to 16
     - `pgsql_16_to_17.sh`: Handles upgrade from PostgreSQL 16 to 17
   - To change versions, create new scripts following the naming pattern `pgsql_X_to_Y.sh`
   - Update the entrypoint.sh script to call the correct upgrade scripts

3. **Docker Compose Configuration**:
   - Modify `pgsql_migration/files/compose.yml` to add or change volume mappings for different PostgreSQL versions

### Example: Modifying for PostgreSQL 14 to 16 Upgrade

```Dockerfile
# In Dockerfile, add:
RUN dnf install -y postgresql14-server postgresql14-contrib
RUN mkdir -p /var/lib/pgsql/14/data
```

```yaml
# In compose.yml, modify:
volumes:
  - ./pg14_data:/var/lib/pgsql/14/data
  - ./pg16_data:/var/lib/pgsql/16/data
```

Then create a new script `pgsql_14_to_16.sh` based on the existing upgrade scripts.

## Notes

- The backup process uses direct file copying instead of Ansible's synchronize module
- The role requires EC2 instance metadata access for volume creation
- Make sure to test the upgrade process in a non-production environment first 