# @summary Configure OpenVoxDB (PuppetDB) with PostgreSQL backend
#
# @param puppetdb_host
#   Host where openvoxdb is running
# @param postgresql_host
#   Host where PostgreSQL is running (may be same as puppetdb_host)
# @param primary_host
#   Primary OpenVox server (needs puppetdb.conf)
# @param puppetdb_port
#   OpenVoxDB port (default 8081)
plan openvoxadm::subplans::configure_openvoxdb (
  Openvoxadm::SingleTargetSpec $puppetdb_host,
  Openvoxadm::SingleTargetSpec $postgresql_host,
  Openvoxadm::SingleTargetSpec $primary_host,
  Integer                      $puppetdb_port = 8081,
) {
  out::message("Configuring OpenVoxDB on ${puppetdb_host} with PostgreSQL on ${postgresql_host}")

  $puppetdb_target = get_targets($puppetdb_host, 1)
  $postgres_target = get_targets($postgresql_host, 1)
  $primary_target  = get_targets($primary_host, 1)

  # Create puppetdb database and user in PostgreSQL (trust auth for local)
  out::message("Creating puppetdb database...")
  run_command(@("SQL"), $postgres_target)
    sudo -u postgres psql -c "CREATE DATABASE puppetdb;" 2>/dev/null || true
    sudo -u postgres psql -c "CREATE USER puppetdb;" 2>/dev/null || true
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE puppetdb TO puppetdb;" 2>/dev/null || true
    sudo -u postgres psql -c "ALTER DATABASE puppetdb OWNER TO puppetdb;" 2>/dev/null || true
    | SQL

  # Configure pg_hba.conf for trust auth from localhost (for openvoxdb)
  out::message("Configuring pg_hba.conf for local trust auth...")
  run_command(@("CMD"), $postgres_target)
    for f in /var/lib/pgsql/data/pg_hba.conf /etc/postgresql/*/main/pg_hba.conf; do
      if [ -f "$f" ]; then
        grep -q "puppetdb.*puppetdb.*trust" "$f" || echo 'host  puppetdb  puppetdb  127.0.0.1/32  trust' >> "$f"
      fi
    done
    | CMD
  run_command('systemctl reload postgresql 2>/dev/null || true', $postgres_target)

  # Configure database.ini for openvoxdb (trust auth - empty password)
  out::message("Configuring database.ini...")
  apply($puppetdb_target) {
    file { '/etc/puppetlabs/puppetdb/conf.d':
      ensure => directory,
      owner  => 'puppetdb',
      group  => 'puppetdb',
      mode   => '0750',
    }

    file { '/etc/puppetlabs/puppetdb/conf.d/database.ini':
      ensure  => file,
      owner   => 'puppetdb',
      group   => 'puppetdb',
      mode    => '0640',
      content => @("INI"),
[database]
subname = //${postgresql_host}:5432/puppetdb
classname = org.postgresql.Driver
username = puppetdb
log_slow_statements = 10
| INI
    }
  }

  # Configure puppetdb.conf on primary server
  out::message("Configuring puppetdb.conf on primary...")
  apply($primary_target) {
    file { '/etc/puppetlabs/puppet':
      ensure => directory,
    }

    file { '/etc/puppetlabs/puppet/puppetdb.conf':
      ensure  => file,
      content => @("CONF"),
[main]
server_urls = https://${puppetdb_host}:${puppetdb_port}
| CONF
    }
  }

  # Add primary cert to openvoxdb allowlist
  out::message("Adding primary to OpenVoxDB certificate allowlist...")
  $primary_certname = openvoxadm::certname($primary_target)
  apply($puppetdb_target) {
    file { '/etc/puppetlabs/puppetdb/certificate-allowlist':
      ensure  => file,
      owner   => 'puppetdb',
      group   => 'puppetdb',
      mode    => '0640',
      content => "${primary_certname}\n",
    }
  }

  # Restart openvoxdb
  out::message("Restarting OpenVoxDB...")
  run_command('systemctl enable --now openvoxdb', $puppetdb_target)

  # Restart puppetserver on primary to pick up puppetdb.conf
  out::message("Restarting OpenVox Server on primary...")
  run_command('systemctl restart openvox-server', $primary_target)

  out::message("OpenVoxDB configured successfully.")
  return({ 'status' => 'openvoxdb_configured' })
}
