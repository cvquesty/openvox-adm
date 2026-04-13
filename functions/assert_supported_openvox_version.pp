# @summary Assert OpenVox version is supported
#
# Currently supports OpenVox 8.x
function openvoxadm::assert_supported_openvox_version (
  Openvoxadm::Openvox_version $version,
  Boolean $permit_unsafe_versions = false,
) >> Struct[{ 'supported' => Boolean }] {
  $supported = ($version =~ /^8\./)

  unless $supported or $permit_unsafe_versions {
    fail("openvox-adm supports OpenVox 8.x. Got version ${version}.")
  }
  return({ 'supported' => $supported })
}
