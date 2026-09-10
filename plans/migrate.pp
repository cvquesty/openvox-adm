# @summary Migrate OpenVox to new host(s)
#
# @param old_primary_host
#   Existing primary to migrate from
# @param new_primary_host
#   New server to become primary
# @param replica_host
#   Optional new replica
# @param primary_postgresql_host
#   Optional dedicated PostgreSQL host
# @param version
#   OpenVox version to install on the new primary
plan openvoxadm::migrate (
  Openvoxadm::SingleTargetSpec           $old_primary_host,
  Openvoxadm::SingleTargetSpec           $new_primary_host,
  Optional[Openvoxadm::SingleTargetSpec] $replica_host = undef,
  Optional[Openvoxadm::SingleTargetSpec] $primary_postgresql_host = undef,
  Openvoxadm::Openvox_version            $version = '8.11.0',
) {
  out::message("Migrating OpenVox from ${old_primary_host} to ${new_primary_host}")

  $all_hosts = openvoxadm::flatten_compact([
    $old_primary_host,
    $new_primary_host,
    $replica_host,
    $primary_postgresql_host,
  ])

  # Verify connectivity
  run_command('hostname', $all_hosts)

  # Backup old primary (returns path to recovery.tar.gz)
  out::message("Backing up old primary...")
  $backup = run_plan('openvoxadm::backup', targets => $old_primary_host)

  # Install on new primary
  out::message("Installing on new primary...")
  run_task('openvoxadm::install_packages', $new_primary_host, version => $version)
  run_command('puppet ssl bootstrap --waitforcert 60', $new_primary_host)

  # Restore backup to new primary using the single recovery tarball
  out::message("Restoring backup to new primary...")
  run_plan('openvoxadm::restore',
    targets    => $new_primary_host,
    input_file => $backup['path'],
    confirm    => true,
  )

  out::message("Migration complete. Old primary: ${old_primary_host}, New primary: ${new_primary_host}")
  return({ 'status' => 'migrated', 'new_primary' => openvoxadm::certname($new_primary_host) })
}
