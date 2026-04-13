# @summary Restore OpenVox primary from backup
#
# @param targets
#   The primary server to restore
# @param input_file
#   Path to the backup tarball
plan openvoxadm::restore (
  Openvoxadm::SingleTargetSpec $targets,
  Pattern[/.*\.tar\.gz$/]      $input_file,
) {
  out::message("Restoring OpenVox from: ${input_file}")

  $recovery_directory = "${dirname($input_file)}/${basename($input_file, '.tar.gz')}"

  # Extract backup
  run_command("mkdir -p ${recovery_directory} && tar -xzf ${input_file} -C ${recovery_directory}", $targets)

  # Stop services
  run_command('systemctl stop openvox-server openvoxdb', $targets, _catch_errors => true)

  # Restore certs
  if file::exists("${recovery_directory}/certs.tar.gz") {
    run_command("tar -xzf ${recovery_directory}/certs.tar.gz -C /etc/puppetlabs/puppet/ssl", $targets)
  }

  # Restore config
  if file::exists("${recovery_directory}/config.tar.gz") {
    run_command("tar -xzf ${recovery_directory}/config.tar.gz -C /etc/puppetlabs/puppet", $targets)
  }

  # Restore environments
  if file::exists("${recovery_directory}/environments.tar.gz") {
    run_command("tar -xzf ${recovery_directory}/environments.tar.gz -C /etc/puppetlabs/code/environments", $targets)
  }

  # Restart services
  run_command('systemctl restart openvox-server openvoxdb', $targets)

  out::message("Restore complete.")
  return({ 'status' => 'restored' })
}
