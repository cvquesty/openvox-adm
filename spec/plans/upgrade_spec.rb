# frozen_string_literal: true

require 'spec_helper'

describe 'openvoxadm::upgrade' do
  include BoltSpec::Plans

  it 'requires primary_host parameter' do
    # Plan should fail without required parameter
    result = run_plan('openvoxadm::upgrade', {})
    expect(result).not_to be_ok
  end

  it 'validates version format' do
    # Invalid version should fail version check
    result = run_plan('openvoxadm::upgrade', {
      'primary_host' => 'primary.example.com',
      'version' => 'invalid'
    })
    expect(result).not_to be_ok
  end
end
