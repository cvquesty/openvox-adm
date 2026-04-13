# @summary Configure OpenVox cluster after package installation
plan openvoxadm::subplans::configure (
  Openvoxadm::SingleTargetSpec           $primary_host,
  Optional[Openvoxadm::SingleTargetSpec] $replica_host = undef,
  Optional[TargetSpec]                   $compiler_hosts = undef,
  Optional[Openvoxadm::SingleTargetSpec] $primary_postgresql_host = undef,
  Optional[Openvoxadm::SingleTargetSpec] $replica_postgresql_host = undef,
  Optional[String]                       $compiler_pool_address = undef,
  Optional[String]                       $internal_compiler_a_pool_address = undef,
  Optional[String]                       $internal_compiler_b_pool_address = undef,
  Optional[String]                       $r10k_remote = undef,
  Enum['running', 'stopped']             $final_agent_state = 'running',
) {
  out::message("Configuring OpenVox cluster...")

  # Configure r10k on primary if remote specified
  if $r10k_remote {
    out::message("Configuring r10k...")
    run_plan('openvoxadm::subplans::configure_r10k',
      primary_host => $primary_host,
      r10k_remote  => $r10k_remote,
    )
  }

  # Start services
  out::message("Starting OpenVox services...")
  run_command('systemctl enable --now openvox-server', $primary_host)

  if $primary_postgresql_host {
    run_command('systemctl enable --now postgresql openvoxdb', $primary_postgresql_host)
  } else {
    run_command('systemctl enable --now postgresql openvoxdb', $primary_host)
  }

  if $compiler_hosts {
    get_targets($compiler_hosts).each |$c| {
      run_command('systemctl enable --now openvox-server', $c)
    }
  }

  out::message("OpenVox cluster configuration complete.")
  return({ 'status' => 'configured' })
}
