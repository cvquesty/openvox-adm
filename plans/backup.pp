# @summary Backup OpenVox primary configuration
#
# @param targets
#   The primary OpenVox server
# @param backup_type
#   'recovery' (default) or 'custom'
# @param output_directory
#   Where to place the backup
plan openvoxadm::backup (
  Openvoxadm::SingleTargetSpec $targets,
  Enum['recovery', 'custom']   $backup_type = 'recovery',
  String                       $output_directory = '/tmp',
) {
  out::message("Backing up OpenVox primary: ${targets}")

  $timestamp = Timestamp.new().strftime('%Y-%m-%dT%H%M%SZ')
  $backup_directory = "${output_directory}/openvox-backup-${timestamp}"

  # Create backup directory
  apply($targets) {
    file { $backup_directory:
      ensure => 'directory',
      owner  => 'root',
      group  => 'root',
      mode   => '0700',
    }
  }

  # Backup CA and SSL certs
  run_command("tar -czf ${backup_directory}/certs.tar.gz -C /etc/puppetlabs/puppet/ssl .", $targets)

  # Backup puppet.conf and config
  run_command("tar -czf ${backup_directory}/config.tar.gz -C /etc/puppetlabs/puppet .", $targets)

  # Backup r10k environments
  run_command("tar -czf ${backup_directory}/environments.tar.gz -C /etc/puppetlabs/code/environments .", $targets, _catch_errors => true)

  # Backup PuppetDB data (if local)
  run_command("tar -czf ${backup_directory}/puppetdb.tar.gz -C /opt/puppetlabs/server/data/puppetdb .", $targets, _catch_errors => true)

  # Create manifest of backup contents
  run_command("ls -la ${backup_directory}/ > ${backup_directory}/MANIFEST.txt", $targets)

  out::message("Backup complete: ${backup_directory}")
  return({ 'path' => $backup_directory })
}
