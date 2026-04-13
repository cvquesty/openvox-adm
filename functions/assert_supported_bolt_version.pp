# @summary Assert that Bolt version is supported
#
# Requires Bolt >= 3.17.0
function openvoxadm::assert_supported_bolt_version () >> Struct[{ 'supported' => Boolean }] {
  $supported_bolt_version = '>= 3.17.0 < 6.0.0'
  $current_bolt_version = openvoxadm::bolt_version()
  $supported = ($current_bolt_version =~ SemVerRange($supported_bolt_version))

  unless $supported {
    fail(@("REASON"/L))
      This version of openvox-adm requires Bolt version ${supported_bolt_version}.

      You are using Bolt version ${current_bolt_version}.

      Please upgrade Bolt and try again.

      | REASON
  }
  return({ 'supported' => $supported })
}
