# @summary Backup CA and SSL certificates only
#
# @param target
#   The primary server
# @param output_directory
#   Where to place the backup
plan openvoxadm::backup_ca (
  Openvoxadm::SingleTargetSpec $target,
  Optional[String]             $output_directory = '/tmp',
) {
  out::message('Backing up CA and SSL certificates')

  $timestamp = Timestamp.new().strftime('%Y-%m-%dT%H%M%SZ')
  $backup_directory = "${output_directory}/openvox-ca-backup-${timestamp}"

  apply($target) {
    file { $backup_directory:
      ensure => 'directory',
      owner  => 'root',
      group  => 'root',
      mode   => '0700',
    }
  }

  run_command("tar -czf ${backup_directory}/ca_backup.tgz -C /etc/puppetlabs/puppet/ssl .", $target)

  out::message("CA backup complete: ${backup_directory}/ca_backup.tgz")
  return({ 'path' => "${backup_directory}/ca_backup.tgz" })
}
