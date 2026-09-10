# @summary Restore CA and SSL certificates from backup
#
# @param target
#   The primary server
# @param file_path
#   Path to the CA backup tarball
# @param recovery_directory
#   Temporary extract directory on the target
# @param confirm
#   Must be true; destructive operation
plan openvoxadm::restore_ca (
  Openvoxadm::SingleTargetSpec $target,
  String                       $file_path,
  Optional[String]             $recovery_directory = '/var/backups/openvox/openvox_recovery',
  Boolean                      $confirm = false,
) {
  unless $confirm {
    fail('openvoxadm::restore_ca is destructive. Pass confirm => true to proceed.')
  }

  out::message('Restoring CA and SSL certificates')

  $quoted_file = shellquote($file_path)
  $quoted_recovery = shellquote($recovery_directory)

  run_command("mkdir -p ${quoted_recovery} && tar -xzf ${quoted_file} -C ${quoted_recovery}", $target)
  run_command("cp -a ${quoted_recovery}/. /etc/puppetlabs/puppet/ssl/", $target)

  out::message("CA restore complete from ${file_path}")
  return({ 'status' => 'ca_restored' })
}
