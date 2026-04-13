# @summary Flatten an array and remove undef values
function openvoxadm::flatten_compact (
  Array $input,
) {
  $input.flatten.filter |$value| {
    $value != undef
  }
}
