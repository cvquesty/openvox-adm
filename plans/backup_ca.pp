# @summary Backup CA and SSL certificates only
#
# @param target
#   The primary server
# @param output_directory
#   Where to place the backup (default: /var/backups/openvox)
plan openvoxadm::backup_ca (
  Openvoxadm::SingleTargetSpec $target,
  Optional[String]             $output_directory = '/var/backups/openvox',
) {
  out::message('Backing up CA and SSL certificates')

  $timestamp = Timestamp.new().strftime('%Y-%m-%dT%H%M%SZ')
  $backup_directory = "${output_directory}/openvox-ca-backup-${timestamp}"
  $quoted_dir = shellquote($backup_directory)

  run_command("mkdir -p ${quoted_dir} && chmod 0700 ${quoted_dir}", $target)

  run_command("tar -czf ${quoted_dir}/ca_backup.tgz -C /etc/puppetlabs/puppet/ssl .", $target)

  out::message("CA backup complete: ${backup_directory}/ca_backup.tgz")
  return({ 'path' => "${backup_directory}/ca_backup.tgz" })
}
