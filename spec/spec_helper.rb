# frozen_string_literal: true

begin
  require 'bolt_spec/plans'
  require 'bolt_spec/run'
  BOLT_SPEC_AVAILABLE = true
rescue LoadError
  BOLT_SPEC_AVAILABLE = false
end

RSpec.configure do |c|
  if BOLT_SPEC_AVAILABLE
    c.include BoltSpec::Plans
    c.include BoltSpec::Run

    c.before :suite do
      if defined?(BoltSpec::Run) && BoltSpec::Run.respond_to?(:init)
        BoltSpec::Run.init
      end
    end
  end
end

# Helper to find fixtures
def fixtures
  File.join(__dir__, 'fixtures')
end
