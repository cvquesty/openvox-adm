# @summary Configure r10k on primary server
plan openvoxadm::subplans::configure_r10k (
  Openvoxadm::SingleTargetSpec $primary_host,
  String                       $r10k_remote,
) {
  out::message("Configuring r10k with remote: ${r10k_remote}")

  # Create r10k config
  $r10k_conf = @("R10K_CONF")
---
:cachedir: '/opt/puppetlabs/puppet/cache/r10k'
:sources:
  :main:
    :remote: '${r10k_remote}'
    :basedir: '/etc/puppetlabs/code/environments'
  | R10K_CONF

  run_command("cat > /etc/puppetlabs/r10k/r10k.yaml << 'EOF'\n${r10k_conf}\nEOF", $primary_host)

  # Run initial r10k deploy
  run_command('r10k deploy environment --puppetfile', $primary_host)

  out::message("r10k configured.")
  return({ 'status' => 'r10k_configured' })
}
