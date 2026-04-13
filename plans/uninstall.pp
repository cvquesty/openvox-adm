# @summary Uninstall OpenVox from targets
#
# @param targets
#   Hosts to uninstall from
plan openvoxadm::uninstall (
  TargetSpec $targets,
) {
  out::message("Uninstalling OpenVox from targets...")

  run_task('openvoxadm::uninstall', $targets)

  out::message("Uninstall complete.")
  return({ 'status' => 'uninstalled' })
}
