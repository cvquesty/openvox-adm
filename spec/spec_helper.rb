# frozen_string_literal: true

require 'bolt_spec/plans'
require 'bolt_spec/run'

RSpec.configure do |c|
  c.include BoltSpec::Plans
  c.include BoltSpec::Run

  c.before :suite do
    BoltSpec::Run.init
  end
end

# Helper to find fixtures
def fixtures
  File.join(__dir__, 'fixtures')
end
