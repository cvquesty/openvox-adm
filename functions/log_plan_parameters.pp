function openvoxadm::log_plan_parameters(Hash $params) {
  out::message("openvox-adm Module version: ${openvoxadm::module_version()}")
  $params.each |$key, $value| {
    out::message("Parameter '${key}': [${value}]")
  }
}
