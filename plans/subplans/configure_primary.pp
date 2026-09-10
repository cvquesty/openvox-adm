# @summary Configure the primary OpenVox server
plan openvoxadm::subplans::configure_primary (
  Openvoxadm::SingleTargetSpec $primary_host,
  Optional[Array[String]]      $dns_alt_names = undef,
  Optional[String]             $r10k_remote = undef,
) {
  out::message("Configuring primary server: ${primary_host}")

  $primary_target = get_targets($primary_host, 1)
  $primary_certname = openvoxadm::certname($primary_target)
  $quoted_certname = shellquote($primary_certname)

  # Update puppet.conf with dns_alt_names if provided
  if $dns_alt_names {
    $alt_names = $dns_alt_names.join(',')
    $quoted_alt = shellquote($alt_names)
    run_command("puppet config set dns_alt_names ${quoted_alt} --section main", $primary_target)
  }

  # Restart puppetserver to pick up config
  run_command('systemctl restart openvox-server', $primary_target)

  # Sign only the primary certname (avoid ca sign --all)
  run_command("puppetserver ca sign --certname ${quoted_certname} 2>/dev/null || true", $primary_target)

  out::message("Primary server configured.")
  return({ 'status' => 'primary_configured' })
}
