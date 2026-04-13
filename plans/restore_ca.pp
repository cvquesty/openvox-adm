# @summary Restore CA and SSL certificates from backup
#
# @param target
#   The primary server
# @param file_path
#   Path to the CA backup tarball
plan openvoxadm::restore_ca (
  Openvoxadm::SingleTargetSpec $target,
  String                       $file_path,
  Optional[String]             $recovery_directory = '/tmp/openvox_recovery',
) {
  out::message('Restoring CA and SSL certificates')

  run_command("mkdir -p ${recovery_directory} && tar -xzf ${file_path} -C ${recovery_directory}", $target)
  run_command("cp -a ${recovery_directory}/* /etc/puppetlabs/puppet/ssl/", $target)

  out::message("CA restore complete from ${file_path}")
  return({ 'status' => 'ca_restored' })
}
