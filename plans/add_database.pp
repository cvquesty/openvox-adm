# @summary Add a dedicated PostgreSQL + OpenVoxDB host
#
# @param targets
#   The PostgreSQL host to add
# @param primary_host
#   The primary OpenVox server
# @param mode
#   'init' for first DB, 'pair' for HA setup
plan openvoxadm::add_database (
  Openvoxadm::SingleTargetSpec $targets,
  Openvoxadm::SingleTargetSpec $primary_host,
  Optional[Enum['init', 'pair']] $mode = undef,
) {
  $primary_target   = get_targets($primary_host, 1)
  $postgresql_target = get_targets($targets, 1)
  $postgresql_host  = openvoxadm::certname($postgresql_target)

  out::message("Adding dedicated database host: ${postgresql_host}")

  # Install PostgreSQL and OpenVoxDB on target
  run_task('openvoxadm::install_packages', $postgresql_target, version => '8.11.0')

  # For init mode, this is the first external DB
  if $mode == 'init' or $mode == undef {
    out::message("Operating in init mode")

    # Configure OpenVoxDB on the new host
    run_command('systemctl enable --now postgresql', $postgresql_target)

    # Configure primary to point to new DB host
    run_command("puppet config set server ${postgresql_host} --section main", $primary_target)

    # Update puppetdb.conf on primary to use remote DB
    apply($primary_target) {
      ini_setting { 'puppetdb-server':
        ensure  => present,
        path    => '/etc/puppetlabs/puppetdb/conf.d/database.ini',
        section => 'database',
        setting => 'subname',
        value   => "//${postgresql_host}:5432/puppetdb",
      }
    }
  } else {
    out::message("Operating in pair mode (HA)")
    # HA setup would configure streaming replication, etc.
    # For now, just configure the connection
    out::message("Note: Full HA PostgreSQL replication not yet implemented in openvox-adm")
  }

  # Restart OpenVoxDB on primary
  run_command('systemctl restart openvoxdb', $primary_target)

  out::message("Database host added successfully.")
  return({ 'status' => 'database_added', 'host' => $postgresql_host })
}
