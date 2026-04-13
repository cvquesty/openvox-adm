require 'bolt'

Puppet::Functions.create_function(:'openvoxadm::bolt_version') do
  def bolt_version
    Bolt::VERSION
  end
end
