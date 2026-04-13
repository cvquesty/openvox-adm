# @summary Check status of OpenVox infrastructure
#
# @param targets
#   The hosts to check status on
plan openvoxadm::status (
  TargetSpec $targets,
) {
  out::message("Checking OpenVox infrastructure status...")

  $results = run_task('openvoxadm::status', $targets)

  return $results
}
