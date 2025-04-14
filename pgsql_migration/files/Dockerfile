# Set Base Image
FROM almalinux:9

# Install dependencies
RUN dnf update -y && \
    dnf install -y shadow-utils && \
    dnf install -y shadow-utils glibc-langpack-en && \
    dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-$(uname -m)/pgdg-redhat-repo-latest.noarch.rpm && \
    dnf install -y postgresql17-server postgresql17-contrib && \
    dnf install -y postgresql16-server postgresql16-contrib && \
    dnf install -y postgresql15-server postgresql15-contrib && \
    dnf clean all

# Create postgres user and group
RUN groupadd -g 26 postgres || true && \
    useradd -u 26 -g 26 -d /var/lib/pgsql -s /bin/bash postgres || true

# Create data directories
RUN mkdir -p /var/lib/pgsql/15/data && \
    mkdir -p /var/lib/pgsql/16/data && \
    mkdir -p /var/lib/pgsql/17/data && \
    mkdir -p /var/lib/pgsql/data && \
    chown -R postgres:postgres /var/lib/pgsql

# Set permissions for data directories
RUN chmod 755 /var/lib/pgsql/15/data && \
    chmod 755 /var/lib/pgsql/16/data && \
    chmod 755 /var/lib/pgsql/17/data && \
    chmod 755 /var/lib/pgsql/data

# Create symbolic links for PostgreSQL binaries
RUN ln -s /usr/pgsql-15/bin /usr/pgsql-15/bin && \
    ln -s /usr/pgsql-16/bin /usr/pgsql-16/bin && \
    ln -s /usr/pgsql-17/bin /usr/pgsql-17/bin

# Copy scripts and set permissions (as root)
COPY ./scripts/ /scripts/
RUN chmod +x /scripts/*.sh

# Now switch to postgres user
USER postgres
WORKDIR /var/lib/pgsql

ENTRYPOINT ["/scripts/entrypoint.sh"]
