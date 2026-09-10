# @summary Restore OpenVox primary from backup
#
# Accepts a single recovery.tar.gz produced by openvoxadm::backup.
# The tarball contains component archives (certs.tar.gz, config.tar.gz, etc.).
#
# @param targets
#   The primary server to restore
# @param input_file
#   Path to the recovery.tar.gz backup tarball on the target
# @param confirm
#   Must be true; destructive operation
plan openvoxadm::restore (
  Openvoxadm::SingleTargetSpec $targets,
  Pattern[/.*\.tar\.gz$/]      $input_file,
  Boolean                      $confirm = false,
) {
  unless $confirm {
    fail('openvoxadm::restore is destructive. Pass confirm => true to proceed.')
  }

  out::message("Restoring OpenVox from: ${input_file}")

  $recovery_directory = "${dirname($input_file)}/${basename($input_file, '.tar.gz')}"
  $quoted_input = shellquote($input_file)
  $quoted_recovery = shellquote($recovery_directory)

  # Extract outer recovery tarball on the target (tarball contains backup basename dir)
  $quoted_parent = shellquote(dirname($input_file))
  run_command("mkdir -p ${quoted_parent} && tar -xzf ${quoted_input} -C ${quoted_parent}", $targets)

  # Stop services
  run_command('systemctl stop openvox-server openvoxdb', $targets, _catch_errors => true)

  # Restore component archives — check existence on the target, not the controller
  $certs_check = run_command("test -f ${quoted_recovery}/certs.tar.gz", $targets, _catch_errors => true)
  if $certs_check.ok {
    run_command("tar -xzf ${quoted_recovery}/certs.tar.gz -C /etc/puppetlabs/puppet/ssl", $targets)
  }

  $config_check = run_command("test -f ${quoted_recovery}/config.tar.gz", $targets, _catch_errors => true)
  if $config_check.ok {
    run_command("tar -xzf ${quoted_recovery}/config.tar.gz -C /etc/puppetlabs/puppet", $targets)
  }

  $env_check = run_command("test -f ${quoted_recovery}/environments.tar.gz", $targets, _catch_errors => true)
  if $env_check.ok {
    run_command("tar -xzf ${quoted_recovery}/environments.tar.gz -C /etc/puppetlabs/code/environments", $targets)
  }

  $pdb_check = run_command("test -f ${quoted_recovery}/puppetdb.tar.gz", $targets, _catch_errors => true)
  if $pdb_check.ok {
    run_command("tar -xzf ${quoted_recovery}/puppetdb.tar.gz -C /opt/puppetlabs/server/data/puppetdb", $targets)
  }

  # Restart services
  run_command('systemctl restart openvox-server openvoxdb', $targets)

  out::message("Restore complete.")
  return({ 'status' => 'restored' })
}
