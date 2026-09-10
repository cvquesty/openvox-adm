# @summary Backup OpenVox primary configuration
#
# Produces a single recovery.tar.gz containing component archives
# (certs, config, environments, puppetdb) suitable for openvoxadm::restore.
#
# @param targets
#   The primary OpenVox server
# @param backup_type
#   'recovery' (default) or 'custom'
# @param output_directory
#   Where to place the backup (default: /var/backups/openvox)
plan openvoxadm::backup (
  Openvoxadm::SingleTargetSpec $targets,
  Enum['recovery', 'custom']   $backup_type = 'recovery',
  String                       $output_directory = '/var/backups/openvox',
) {
  out::message("Backing up OpenVox primary: ${targets}")

  $timestamp = Timestamp.new().strftime('%Y-%m-%dT%H%M%SZ')
  $backup_basename = "openvox-backup-${timestamp}"
  $backup_directory = "${output_directory}/${backup_basename}"
  $recovery_tarball = "${backup_directory}.tar.gz"

  $quoted_output = shellquote($output_directory)
  $quoted_dir = shellquote($backup_directory)
  $quoted_tarball = shellquote($recovery_tarball)
  $quoted_basename = shellquote($backup_basename)

  # Create backup parent and working directory
  run_command("mkdir -p ${quoted_dir} && chmod 0700 ${quoted_dir}", $targets)

  # Backup CA and SSL certs
  run_command("tar -czf ${quoted_dir}/certs.tar.gz -C /etc/puppetlabs/puppet/ssl .", $targets)

  # Backup puppet.conf and config
  run_command("tar -czf ${quoted_dir}/config.tar.gz -C /etc/puppetlabs/puppet .", $targets)

  # Backup r10k environments
  run_command("tar -czf ${quoted_dir}/environments.tar.gz -C /etc/puppetlabs/code/environments .", $targets, _catch_errors => true)

  # Backup PuppetDB data (if local)
  run_command("tar -czf ${quoted_dir}/puppetdb.tar.gz -C /opt/puppetlabs/server/data/puppetdb .", $targets, _catch_errors => true)

  # Create manifest of backup contents
  run_command("ls -la ${quoted_dir}/ > ${quoted_dir}/MANIFEST.txt", $targets)

  # Wrap directory into a single recovery tarball for restore/migrate
  run_command("tar -czf ${quoted_tarball} -C ${quoted_output} ${quoted_basename}", $targets)

  out::message("Backup complete: ${recovery_tarball}")
  return({ 'path' => $recovery_tarball, 'directory' => $backup_directory })
}
