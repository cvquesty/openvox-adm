# @summary Add a dedicated PostgreSQL + OpenVoxDB host
#
# @param targets
#   The PostgreSQL host to add
# @param primary_host
#   The primary OpenVox server
# @param mode
#   'init' for first DB, 'pair' for HA setup
# @param version
#   OpenVox version to install
plan openvoxadm::add_database (
  Openvoxadm::SingleTargetSpec $targets,
  Openvoxadm::SingleTargetSpec $primary_host,
  Optional[Enum['init', 'pair']] $mode = undef,
  Openvoxadm::Openvox_version    $version = '8.11.0',
) {
  $primary_target    = get_targets($primary_host, 1)
  $postgresql_target = get_targets($targets, 1)
  $postgresql_host   = openvoxadm::certname($postgresql_target)

  out::message("Adding dedicated database host: ${postgresql_host}")

  # Install PostgreSQL and OpenVoxDB on target
  run_task('openvoxadm::install_packages', $postgresql_target, version => $version)

  # For init mode, this is the first external DB
  if $mode == 'init' or $mode == undef {
    out::message("Operating in init mode")

    # Configure PostgreSQL host (agent points at primary; start services)
    run_plan('openvoxadm::subplans::configure_postgresql',
      postgresql_host => $postgresql_target,
      primary_host    => $primary_target,
    )

    # Configure OpenVoxDB on the DB host and point primary puppetdb.conf at it
    # (do NOT set puppet config server to the DB host — that would break the primary)
    run_plan('openvoxadm::subplans::configure_openvoxdb',
      puppetdb_host   => $postgresql_target,
      postgresql_host => $postgresql_target,
      primary_host    => $primary_target,
    )
  } else {
    out::message("Operating in pair mode (HA)")
    # HA setup would configure streaming replication, etc.
    out::message("Note: Full HA PostgreSQL replication not yet implemented in openvox-adm")
    run_plan('openvoxadm::subplans::configure_postgresql',
      postgresql_host => $postgresql_target,
      primary_host    => $primary_target,
    )
  }

  out::message("Database host added successfully.")
  return({ 'status' => 'database_added', 'host' => $postgresql_host })
}
