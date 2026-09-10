# @summary Log plan parameters, redacting secrets
function openvoxadm::log_plan_parameters(Hash $params) {
  out::message("openvox-adm Module version: ${openvoxadm::module_version()}")
  $sensitive_pattern = /(?i)(key|secret|password|token|pem|credential)/
  $params.each |$key, $value| {
    if $key =~ $sensitive_pattern {
      out::message("Parameter '${key}': [REDACTED]")
    } else {
      out::message("Parameter '${key}': [${value}]")
    }
  }
}
