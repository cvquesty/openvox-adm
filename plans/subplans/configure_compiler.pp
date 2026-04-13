# @summary Configure a compiler node
plan openvoxadm::subplans::configure_compiler (
  Openvoxadm::SingleTargetSpec $compiler_host,
  Openvoxadm::SingleTargetSpec $primary_host,
) {
  out::message("Configuring compiler: ${compiler_host}")

  # Set server to primary for CA operations
  run_command("puppet config set server ${primary_host} --section main", $compiler_host)
  run_command("puppet config set ca_server ${primary_host} --section main", $compiler_host)
  run_command("puppet config set ca false --section main", $compiler_host)

  # Restart compiler
  run_command('systemctl restart openvox-server', $compiler_host)

  out::message("Compiler configured.")
  return({ 'status' => 'compiler_configured' })
}
