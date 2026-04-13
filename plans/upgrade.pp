# @summary Upgrade an OpenVox cluster to a new version
#
# @param primary_host
#   The primary OpenVox server
# @param replica_host
#   Optional replica server
# @param compiler_hosts
#   Optional list of compiler hosts
# @param primary_postgresql_host
#   Optional dedicated PostgreSQL host
# @param replica_postgresql_host
#   Optional replica PostgreSQL host
# @param version
#   Target OpenVox version (e.g., '8.12.0')
# @param final_agent_state
#   State of puppet agent after upgrade (running/stopped)
plan openvoxadm::upgrade (
  Openvoxadm::SingleTargetSpec           $primary_host,
  Optional[Openvoxadm::SingleTargetSpec] $replica_host = undef,
  Optional[TargetSpec]                   $compiler_hosts = undef,
  Optional[Openvoxadm::SingleTargetSpec] $primary_postgresql_host = undef,
  Optional[Openvoxadm::SingleTargetSpec] $replica_postgresql_host = undef,

  Openvoxadm::Openvox_version            $version = '8.11.0',
  Enum['running', 'stopped']             $final_agent_state = 'running',
  Boolean                                $permit_unsafe_versions = false,
) {
  openvoxadm::assert_supported_bolt_version()
  openvoxadm::assert_supported_openvox_version($version, $permit_unsafe_versions)

  out::message("Upgrading OpenVox cluster to ${version}...")

  $all_targets = openvoxadm::flatten_compact([
    $primary_host,
    $replica_host,
    $compiler_hosts,
    $primary_postgresql_host,
    $replica_postgresql_host,
  ])

  # Stop Puppet services on all nodes
  out::message("Stopping services...")
  run_command('systemctl stop puppet openvox-server openvoxdb 2>/dev/null || true', $all_targets, _catch_errors => true)

  # Upgrade packages
  out::message("Upgrading packages to ${version}...")
  parallelize($all_targets) |$target| {
    run_task('openvoxadm::install_packages', $target, version => $version)
  }

  # Restart services
  out::message("Starting services...")
  run_command('systemctl enable --now openvox-server', $primary_host)
  if $primary_postgresql_host {
    run_command('systemctl enable --now postgresql openvoxdb', $primary_postgresql_host)
  } else {
    run_command('systemctl enable --now postgresql openvoxdb', $primary_host)
  }
  if $replica_host {
    run_command('systemctl enable --now openvox-server', $replica_host)
  }
  if $compiler_hosts {
    run_command('systemctl enable --now openvox-server', $compiler_hosts)
  }

  # Final agent state
  if $final_agent_state == 'running' {
    run_command('systemctl start puppet', $all_targets, _catch_errors => true)
  }

  out::message("Upgrade to ${version} complete.")
  return({ 'status' => 'upgraded', 'version' => $version })
}
