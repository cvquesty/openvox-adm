# @summary Configure dedicated PostgreSQL + OpenVoxDB host
plan openvoxadm::subplans::configure_postgresql (
  Openvoxadm::SingleTargetSpec $postgresql_host,
  Openvoxadm::SingleTargetSpec $primary_host,
) {
  out::message("Configuring PostgreSQL host: ${postgresql_host}")

  # Configure OpenVoxDB to connect to primary
  run_command("puppet config set server ${primary_host} --section main", $postgresql_host)

  # Start PostgreSQL and OpenVoxDB
  run_command('systemctl enable --now postgresql', $postgresql_host)
  run_command('systemctl enable --now openvoxdb', $postgresql_host)

  out::message("PostgreSQL host configured.")
  return({ 'status' => 'postgresql_configured' })
}
