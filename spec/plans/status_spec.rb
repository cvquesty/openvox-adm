# frozen_string_literal: true

require 'spec_helper'

describe 'openvoxadm::status' do
  include BoltSpec::Plans

  it 'calls status task on targets' do
    allow_task('openvoxadm::status').always_return({ 'output' => 'ok' })
    expect(run_plan('openvoxadm::status', 'targets' => ['primary.example.com'])).to be_ok
  end
end
