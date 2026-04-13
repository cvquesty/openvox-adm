Puppet::Functions.create_function(:'openvoxadm::module_version', Puppet::Functions::InternalFunction) do
  dispatch :module_version do
    scope_param
  end

  def module_version(scope)
    scope.compiler.environment.module('openvoxadm').version
  end
end
