# @summary Install OpenVox packages on all nodes
#
# Handles package installation for primary, compilers, database hosts, and replicas.
plan openvoxadm::subplans::install (
  Openvoxadm::SingleTargetSpec           $primary_host,
  Optional[Openvoxadm::SingleTargetSpec] $replica_host = undef,
  Optional[TargetSpec]                   $compiler_hosts = undef,
  Optional[Openvoxadm::SingleTargetSpec] $primary_postgresql_host = undef,
  Optional[Openvoxadm::SingleTargetSpec] $replica_postgresql_host = undef,
  Openvoxadm::Openvox_version            $version = '8.11.0',
  Optional[Array[String]]                $dns_alt_names = undef,
  Optional[String]                       $r10k_remote = undef,
  Optional[String]                       $stagingdir = undef,
  Optional[String]                       $uploaddir = undef,
) {
  out::message("Installing OpenVox ${version} on cluster...")

  # Collect all targets, dropping undef optional hosts
  $all_targets = get_targets(openvoxadm::flatten_compact([
    $primary_host,
    $replica_host,
    $compiler_hosts,
    $primary_postgresql_host,
    $replica_postgresql_host,
  ])).unique

  # Install openvox-release repo and packages in parallel
  parallelize($all_targets) |$target| {
    run_task('openvoxadm::install_packages', $target,
      version => $version,
    )
  }

  # Bootstrap certificates on primary first
  out::message("Bootstrapping certificates on primary...")
  run_command('puppet ssl bootstrap --waitforcert 60', $primary_host)

  # Configure primary server
  out::message("Configuring primary server...")
  run_plan('openvoxadm::subplans::configure_primary',
    primary_host  => $primary_host,
    dns_alt_names => $dns_alt_names,
    r10k_remote   => $r10k_remote,
  )

  # If compilers exist, bootstrap and configure them
  if $compiler_hosts {
    out::message("Configuring compilers...")
    get_targets($compiler_hosts).each |$compiler| {
      run_command('puppet ssl bootstrap --waitforcert 60', $compiler)
      run_plan('openvoxadm::subplans::configure_compiler',
        compiler_host => $compiler,
        primary_host  => $primary_host,
      )
    }
  }

  # Determine where openvoxdb is running
  $puppetdb_host = $primary_postgresql_host ? {
    undef   => $primary_host,
    default => $primary_postgresql_host,
  }

  # If dedicated PostgreSQL, configure it (installs postgresql + openvoxdb)
  if $primary_postgresql_host {
    out::message("Configuring PostgreSQL host...")
    run_plan('openvoxadm::subplans::configure_postgresql',
      postgresql_host => $primary_postgresql_host,
      primary_host    => $primary_host,
    )
  } else {
    # Co-located on primary: ensure openvoxdb is enabled
    out::message("Enabling OpenVoxDB on primary...")
    run_command('systemctl enable --now openvoxdb', $primary_host)
  }

  # Configure OpenVoxDB with PostgreSQL backend
  out::message("Configuring OpenVoxDB...")
  run_plan('openvoxadm::subplans::configure_openvoxdb',
    puppetdb_host   => $puppetdb_host,
    postgresql_host => $puppetdb_host,
    primary_host    => $primary_host,
  )

  return({ 'status' => 'installed', 'hosts' => $all_targets.map |$t| { $t.name } })
}
