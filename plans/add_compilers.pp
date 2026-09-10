# @summary Add new compilers to an OpenVox architecture
#
# @param avail_group_letter
#   Either 'A' or 'B' for availability group assignment
# @param compiler_hosts
#   Hostnames of the new compilers
# @param dns_alt_names
#   DNS alt names for compiler certs
# @param primary_host
#   The primary OpenVox server
# @param primary_postgresql_host
#   Optional dedicated PostgreSQL host (if using separate DB)
# @param version
#   OpenVox version to install on compilers
plan openvoxadm::add_compilers (
  Enum['A', 'B']                         $avail_group_letter = 'A',
  Optional[Array[String[1]]]             $dns_alt_names = undef,
  TargetSpec                             $compiler_hosts,
  Openvoxadm::SingleTargetSpec           $primary_host,
  Optional[Openvoxadm::SingleTargetSpec] $primary_postgresql_host = undef,
  Openvoxadm::Openvox_version            $version = '8.11.0',
) {
  $compiler_targets = get_targets($compiler_hosts)
  $primary_target   = get_targets($primary_host, 1)

  out::message("Adding ${compiler_targets.size} compiler(s) to availability group ${avail_group_letter}...")

  # Stop OpenVoxDB on primary/postgresql to allow cert updates
  if $primary_postgresql_host {
    run_command('systemctl stop openvoxdb', $primary_postgresql_host)
  } else {
    run_command('systemctl stop openvoxdb', $primary_target)
  }

  # Add compilers to OpenVoxDB allowlist
  $allowlist_target = $primary_postgresql_host ? {
    undef   => $primary_target,
    default => get_targets($primary_postgresql_host, 1),
  }

  apply($allowlist_target) {
    $compiler_targets.each |$compiler| {
      $certname = openvoxadm::certname($compiler)
      file_line { "openvoxdb-allow-${certname}":
        path => '/etc/puppetlabs/puppetdb/certificate-allowlist',
        line => $certname,
      }
    }
  }

  # Install and configure each compiler
  parallelize($compiler_targets) |$compiler| {
    $dns_names = $dns_alt_names ? {
      undef   => undef,
      default => $dns_alt_names[0],  # simplified: use first entry for all
    }

    # Install packages
    run_task('openvoxadm::install_packages', $compiler, version => $version)

    # Bootstrap cert
    run_command('puppet ssl bootstrap --waitforcert 60', $compiler)

    # Configure as compiler (ca=false, point to primary)
    run_plan('openvoxadm::subplans::configure_compiler',
      compiler_host => $compiler,
      primary_host  => $primary_target,
    )

    # Set availability group in puppet.conf
    run_command("puppet config set openvoxadm_availability_group ${avail_group_letter} --section main", $compiler)

    # Start compiler
    run_command('systemctl enable --now openvox-server', $compiler)
  }

  # Restart OpenVoxDB
  run_command('systemctl start openvoxdb', $allowlist_target)

  out::message("Compilers added successfully.")
  return({ 'status' => 'compilers_added', 'hosts' => $compiler_targets.map |$t| { $t.name } })
}
