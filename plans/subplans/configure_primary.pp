# @summary Configure the primary OpenVox server
plan openvoxadm::subplans::configure_primary (
  Openvoxadm::SingleTargetSpec $primary_host,
  Optional[Array[String]]      $dns_alt_names = undef,
  Optional[String]             $r10k_remote = undef,
) {
  out::message("Configuring primary server: ${primary_host}")

  # Update puppet.conf with dns_alt_names if provided
  if $dns_alt_names {
    $alt_names = $dns_alt_names.join(',')
    run_command("puppet config set dns_alt_names ${alt_names} --section main", $primary_host)
  }

  # Restart puppetserver to pick up config
  run_command('systemctl restart openvox-server', $primary_host)

  # Sign any pending certs (self-sign primary)
  run_command('puppetserver ca sign --all 2>/dev/null || true', $primary_host)

  out::message("Primary server configured.")
  return({ 'status' => 'primary_configured' })
}
