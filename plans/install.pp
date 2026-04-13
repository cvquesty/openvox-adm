# @summary Install a new OpenVox cluster
#
# @param primary_host
#   The primary OpenVox server (runs CA, cert signing, r10k)
# @param replica_host
#   Optional replica server for HA
# @param compiler_hosts
#   Optional list of compiler hosts (for large/extra-large)
# @param primary_postgresql_host
#   Optional dedicated PostgreSQL host (extra-large)
# @param replica_postgresql_host
#   Optional replica PostgreSQL host (extra-large HA)
# @param version
#   OpenVox version to install (e.g., '8.11.0')
# @param r10k_remote
#   Git remote URL for r10k control repo
# @param dns_alt_names
#   Additional DNS names for the primary server cert
# @param compiler_pool_address
#   Load balancer address for compilers (if using LB)
plan openvoxadm::install (
  # Standard
  Openvoxadm::SingleTargetSpec           $primary_host,
  Optional[Openvoxadm::SingleTargetSpec] $replica_host = undef,

  # Large / Extra Large
  Optional[TargetSpec]                   $compiler_hosts = undef,
  Optional[TargetSpec]                   $legacy_compilers = undef,
  Optional[Openvoxadm::SingleTargetSpec] $primary_postgresql_host = undef,
  Optional[Openvoxadm::SingleTargetSpec] $replica_postgresql_host = undef,

  # Common Configuration
  Openvoxadm::Openvox_version            $version = '8.11.0',
  Optional[Array[String]]                $dns_alt_names = undef,
  Optional[String]                       $compiler_pool_address = undef,
  Optional[String]                       $internal_compiler_a_pool_address = undef,
  Optional[String]                       $internal_compiler_b_pool_address = undef,

  # r10k / Code deployment
  Optional[String]                       $r10k_remote = undef,
  Optional[String]                       $r10k_private_key_file = undef,
  Optional[Openvoxadm::Pem]              $r10k_private_key_content = undef,

  # Other
  Optional[String]                       $stagingdir = undef,
  Optional[String]                       $uploaddir = undef,
  Enum['running', 'stopped']             $final_agent_state = 'running',
  Boolean                                $permit_unsafe_versions = false,
) {
  # Log parameters
  openvoxadm::log_plan_parameters({
    'primary_host'            => $primary_host,
    'replica_host'            => $replica_host,
    'compiler_hosts'          => $compiler_hosts,
    'primary_postgresql_host' => $primary_postgresql_host,
    'version'                 => $version,
  })

  openvoxadm::assert_supported_bolt_version()
  openvoxadm::assert_supported_openvox_version($version, $permit_unsafe_versions)

  # Install packages on all nodes
  $install_result = run_plan('openvoxadm::subplans::install',
    primary_host            => $primary_host,
    replica_host            => $replica_host,
    compiler_hosts          => $compiler_hosts,
    primary_postgresql_host => $primary_postgresql_host,
    replica_postgresql_host => $replica_postgresql_host,
    version                 => $version,
    dns_alt_names           => $dns_alt_names,
    r10k_remote             => $r10k_remote,
    stagingdir              => $stagingdir,
    uploaddir               => $uploaddir,
  )

  # Configure the cluster
  $configure_result = run_plan('openvoxadm::subplans::configure',
    primary_host                     => $primary_host,
    replica_host                     => $replica_host,
    compiler_hosts                   => $compiler_hosts,
    primary_postgresql_host          => $primary_postgresql_host,
    replica_postgresql_host          => $replica_postgresql_host,
    compiler_pool_address            => $compiler_pool_address,
    internal_compiler_a_pool_address => $internal_compiler_a_pool_address,
    internal_compiler_b_pool_address => $internal_compiler_b_pool_address,
    r10k_remote                      => $r10k_remote,
    final_agent_state                => $final_agent_state,
  )

  return([$install_result, $configure_result])
}
