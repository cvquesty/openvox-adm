# @summary Add or replace a replica host for HA
#
# @param primary_host
#   The primary OpenVox server
# @param replica_host
#   The replica hostname to add
# @param replica_postgresql_host
#   Optional dedicated PostgreSQL for replica (XL architecture)
plan openvoxadm::add_replica (
  Openvoxadm::SingleTargetSpec           $primary_host,
  Openvoxadm::SingleTargetSpec           $replica_host,
  Optional[Openvoxadm::SingleTargetSpec] $replica_postgresql_host = undef,
) {
  $primary_target            = get_targets($primary_host, 1)
  $replica_target            = get_targets($replica_host, 1)
  $replica_postgresql_target = get_targets($replica_postgresql_host, 1)

  out::message("Adding replica host: ${replica_host}")

  # Determine availability group (opposite of primary)
  # For simplicity, assume primary is A, replica is B
  $replica_avail_group = 'B'

  # Stop puppet on primary
  run_command('systemctl stop puppet', $primary_target, _catch_errors => true)

  # Install packages on replica
  run_task('openvoxadm::install_packages', $replica_target, version => '8.11.0')

  # Bootstrap cert on replica
  run_command('puppet ssl bootstrap --waitforcert 60', $replica_target)

  # Configure replica as secondary server
  run_command("puppet config set server ${primary_host} --section main", $replica_target)
  run_command("puppet config set ca_server ${primary_host} --section main", $replica_target)
  run_command("puppet config set openvoxadm_role server --section main", $replica_target)
  run_command("puppet config set openvoxadm_availability_group ${replica_avail_group} --section main", $replica_target)

  # Start replica
  run_command('systemctl enable --now openvox-server', $replica_target)

  # If replica has its own PostgreSQL
  if $replica_postgresql_host {
    run_task('openvoxadm::install_packages', $replica_postgresql_target, version => '8.11.0')
    run_command('systemctl enable --now postgresql openvoxdb', $replica_postgresql_target)
  }

  out::message("Replica added successfully.")
  return({ 'status' => 'replica_added', 'host' => openvoxadm::certname($replica_target) })
}
