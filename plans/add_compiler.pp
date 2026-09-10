# @summary Add a single compiler (deprecated, use add_compilers)
#
# @param avail_group_letter
#   Either 'A' or 'B'
# @param compiler_host
#   The compiler hostname
# @param dns_alt_names
#   DNS alt names
# @param primary_host
#   Primary server
# @param primary_postgresql_host
#   Optional PostgreSQL host
# @param version
#   OpenVox version to install
plan openvoxadm::add_compiler (
  Enum['A', 'B']                         $avail_group_letter = 'A',
  Optional[String[1]]                    $dns_alt_names = undef,
  Openvoxadm::SingleTargetSpec           $compiler_host,
  Openvoxadm::SingleTargetSpec           $primary_host,
  Optional[Openvoxadm::SingleTargetSpec] $primary_postgresql_host = undef,
  Openvoxadm::Openvox_version            $version = '8.11.0',
) {
  out::message('Warning: add_compiler is deprecated. Use add_compilers instead.')
  run_plan('openvoxadm::add_compilers',
    avail_group_letter      => $avail_group_letter,
    dns_alt_names           => $dns_alt_names ? { undef => undef, default => Array($dns_alt_names) },
    compiler_hosts          => $compiler_host,
    primary_host            => $primary_host,
    primary_postgresql_host => $primary_postgresql_host,
    version                 => $version,
  )
}
