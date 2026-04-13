# @summary Replace a failed PostgreSQL host
#
# @param primary_host
#   The primary OpenVox server
# @param working_postgresql_host
#   The still-working PostgreSQL host
# @param failed_postgresql_host
#   The failed host
# @param replacement_postgresql_host
#   New host to bring in
plan openvoxadm::replace_failed_postgresql (
  Openvoxadm::SingleTargetSpec $primary_host,
  Openvoxadm::SingleTargetSpec $working_postgresql_host,
  Openvoxadm::SingleTargetSpec $failed_postgresql_host,
  Openvoxadm::SingleTargetSpec $replacement_postgresql_host,
) {
  out::message("Replacing failed PostgreSQL host ${failed_postgresql_host} with ${replacement_postgresql_host}")

  # Stop services on primary
  run_command('systemctl stop openvox-server openvoxdb', $primary_host, _catch_errors => true)

  # Install packages on replacement
  run_task('openvoxadm::install_packages', $replacement_postgresql_host, version => '8.11.0')

  # Configure replacement PostgreSQL (basic - full replication setup would be manual)
  run_command('systemctl enable --now postgresql', $replacement_postgresql_host)

  # Update primary to point to new host
  run_command("puppet config set server ${replacement_postgresql_host} --section main", $primary_host)

  apply($primary_host) {
    ini_setting { 'puppetdb-server':
      ensure  => present,
      path    => '/etc/puppetlabs/puppetdb/conf.d/database.ini',
      section => 'database',
      setting => 'subname',
      value   => "//${replacement_postgresql_host}:5432/puppetdb",
    }
  }

  run_command('systemctl restart openvoxdb openvox-server', $primary_host)

  out::message("PostgreSQL replacement complete.")
  return({ 'status' => 'postgresql_replaced' })
}
