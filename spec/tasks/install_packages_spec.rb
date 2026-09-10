# frozen_string_literal: true

require 'spec_helper'

describe 'openvoxadm::install_packages' do
  let(:task_script) do
    File.read(File.expand_path('../../../tasks/install_packages.sh', __FILE__))
  end

  it 'honors VERSION pin for yum installs' do
    expect(task_script).to match(/openvox-server-\$\{VERSION\}/)
    expect(task_script).to match(/openvox-agent-\$\{VERSION\}/)
    expect(task_script).to match(/openvoxdb-\$\{VERSION\}/)
  end

  it 'honors VERSION pin for apt installs' do
    expect(task_script).to match(/openvox-server=\$\{VERSION\}\*/)
    expect(task_script).to match(/openvoxdb=\$\{VERSION\}\*/)
  end

  it 'uses curl --fail for repo downloads' do
    expect(task_script).to include('curl --fail')
    expect(task_script).not_to match(/curl -sL/)
  end

  it 'defaults PT_version when unset' do
    expect(task_script).to include('PT_version:-8.11.0')
  end
end
