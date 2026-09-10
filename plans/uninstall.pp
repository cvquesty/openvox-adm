# @summary Uninstall OpenVox from targets
#
# @param targets
#   Hosts to uninstall from
# @param confirm
#   Must be true; destructive operation
plan openvoxadm::uninstall (
  TargetSpec $targets,
  Boolean    $confirm = false,
) {
  unless $confirm {
    fail('openvoxadm::uninstall is destructive. Pass confirm => true to proceed.')
  }

  out::message("Uninstalling OpenVox from targets...")

  run_task('openvoxadm::uninstall', $targets)

  out::message("Uninstall complete.")
  return({ 'status' => 'uninstalled' })
}
