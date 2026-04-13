# Backup and Restore

## Backup

```bash
# Full backup
bolt plan run openvoxadm::backup \
  --targets primary.example.com \
  --params '{"output_directory":"/var/backups/openvox"}'

# CA certs only
bolt plan run openvoxadm::backup_ca \
  --targets primary.example.com
```

Backups include:
- CA and SSL certificates
- puppet.conf and configuration
- r10k environments
- PuppetDB data (if local)

## Restore

```bash
# Full restore
bolt plan run openvoxadm::restore \
  --targets primary.example.com \
  --params '{"input_file":"/var/backups/openvox/openvox-backup-2026-04-13T120000Z.tar.gz"}'

# Restore CA only
bolt plan run openvoxadm::restore_ca \
  --targets primary.example.com \
  --params '{"file_path":"/var/backups/openvox/ca_backup.tgz"}'
```

## PostgreSQL Replacement

If PostgreSQL fails, use:

```bash
bolt plan run openvoxadm::replace_failed_postgresql \
  --params '{
    "primary_host":"primary.example.com",
    "working_postgresql_host":"db1.example.com",
    "failed_postgresql_host":"db2.example.com",
    "replacement_postgresql_host":"db3.example.com"
  }'
```
