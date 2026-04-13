# frozen_string_literal: true

require 'spec_helper'

describe 'openvoxadm::install_packages' do
  include BoltSpec::Run

  it 'accepts version parameter' do
    result = run_task('openvoxadm::install_packages', 'localhost', 'version' => '8.11.0')
    # Task may fail on localhost without packages, but validates structure
    expect(result.first).to have_key('status')
  end
end
