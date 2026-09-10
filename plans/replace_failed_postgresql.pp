# @summary Replace a failed PostgreSQL host
#
# @param primary_host
#   The primary OpenVox server
# @param working_postgresql_host
#   The still-working PostgreSQL host
# @param failed_postgresql_host
#   The failed host
# @param replacement_postgresql_host
#   New host to bring in
# @param version
#   OpenVox version to install on the replacement
plan openvoxadm::replace_failed_postgresql (
  Openvoxadm::SingleTargetSpec $primary_host,
  Openvoxadm::SingleTargetSpec $working_postgresql_host,
  Openvoxadm::SingleTargetSpec $failed_postgresql_host,
  Openvoxadm::SingleTargetSpec $replacement_postgresql_host,
  Openvoxadm::Openvox_version  $version = '8.11.0',
) {
  $primary_target = get_targets($primary_host, 1)
  $replacement_target = get_targets($replacement_postgresql_host, 1)

  out::message("Replacing failed PostgreSQL host ${failed_postgresql_host} with ${replacement_postgresql_host}")

  # Stop services on primary
  run_command('systemctl stop openvox-server openvoxdb', $primary_target, _catch_errors => true)

  # Install packages on replacement
  run_task('openvoxadm::install_packages', $replacement_target, version => $version)

  # Configure replacement PostgreSQL + OpenVoxDB correctly
  # (do NOT set puppet config server to the DB host)
  run_plan('openvoxadm::subplans::configure_postgresql',
    postgresql_host => $replacement_target,
    primary_host    => $primary_target,
  )

  run_plan('openvoxadm::subplans::configure_openvoxdb',
    puppetdb_host   => $replacement_target,
    postgresql_host => $replacement_target,
    primary_host    => $primary_target,
  )

  run_command('systemctl restart openvoxdb openvox-server', $primary_target)

  out::message("PostgreSQL replacement complete. Working host reference: ${working_postgresql_host}")
  return({ 'status' => 'postgresql_replaced' })
}
