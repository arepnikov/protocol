#!/usr/bin/env -S ruby --disable-gems

require "tempfile"
ENV["GEM_HOME"] = Dir.mktmpdir("rubygems-#{File.basename($PROGRAM_NAME, ".rb")}")

require "rubygems" or abort "Invoke ruby with --disable-gems"
require "bundler/inline"

require_relative "./primitive_reflection"

gemfile do
  source "https://rubygems.org"

  gem "evt-reflect", require: "reflect", path: "/Users/visuality/development/eventide_project/reflect/"
  # gem "evt-virtual", require: "virtual", path: "/Users/visuality/development/eventide_project/validate/"

  gem "evt-schema", require: "schema"
  require 'json'
end

def assert(details, result)
  case result
  when true   then puts "assert #{details}"
  when false  then puts "EXPECTED TO BE ASSERT: (#{details}) but it is not"
  else raise 'unsupported'
  end
end

def refute(details, result)
  case result
  when true  then puts "EXPECTED TO BE REFUTE: (#{details}) but it is not"
  when false   then puts "refute #{details}"
  else raise 'unsupported'
  end
end

class Example
  attr_accessor :some_attr

  module Validate
    def self.call(example, state = :present)
      case state
      when :present
        !example.some_attr.nil?
      when :nil
        example.some_attr.nil?
      else
        raise "unsupported state '#{state}'"
      end
    end
  end
end

# withouth scenarious
module SimpleValidate
  extend self

  def call(subject, state=nil)
    validator_reflection = validator_reflection(subject)

    validator = validator_reflection.constant
    validate(validator, subject, state)
  end

  def validator_reflection(subject)
    Reflect.(subject, :Validate, strict: true)
  end

  def validate(validator, subject, state)
    method = validator.method(:call)

    result = nil
    case method.parameters.length
    when 1
      if !state.nil?
        raise Error, "State argument was supplied but the validator does not provide a state parameter (Validator: #{validator})"
      end

      result = validator.public_send :call, subject
    when 2
      result = validator.public_send :call, subject, state
    end

    unless result.is_a?(TrueClass) || result.is_a?(FalseClass)
      raise Error, "Result must be boolean. The result is a #{result.class}. (Validator: #{validator})"
    end

    result
  end
end

module UnwrappedValidate
  extend self

  def call(subject, state=nil)
    validator_reflection = Reflect.(subject, :Validate, strict: true)

    if state.nil?
      # it uses carrying
      validator_reflection.(:call) # reflaction actuator
    else
      validator = validator_reflection.constant # reflection#target
      # it might use carrying, if we allow to provide more arguments somehow.
      validator.public_send :call, subject, state
    end
  end
end

module NewReflection
  module UnwrappedValidate
    extend self

    def call(subject, state=nil)
      # validator_reflection = Reflect.(subject, :Validate, strict: true)
      # validator_reflection = Reflect::Reflection.build(subject, :Validate, strict: true, ancestors: false)
      validator_reflection = PrimitiveReflection.new(subject, Example::Validate)

      if state.nil?
        # it uses carrying
        validator_reflection.(:call) # reflaction actuator
      else
        # validator = validator_reflection.constant # reflection#target
        # validator.public_send :call, subject, state
        validator_reflection.(:call, state)
      end
    end
  end
end

p "===== SimpleValidate ====="
e = Example.new # some_attr is nil

valid = SimpleValidate.(e, :present)
refute("valid", valid)

e.some_attr = 'something' # some_attr is no longer nil
valid = SimpleValidate.(e, :present)
assert("valid", valid)

p "===== UnwrappedValidate ====="
e = Example.new # some_attr is nil

# puts "\ntest: no state (expect :present), but attr is empty"
valid = UnwrappedValidate.(e)
refute("valid", valid)

# puts "\ntest: state: :present, but attr is empty"
valid = UnwrappedValidate.(e, :present)
refute("valid", valid)

# puts "\ntest: state: :nil and attr is empty"
valid = UnwrappedValidate.(e, :nil)
assert("valid", valid)

# puts "\ntest: no state (expect :present), attr isn't empty"
e.some_attr = 'something' # some_attr is no longer nil
valid = UnwrappedValidate.(e)
assert("valid", valid)

# puts "\ntest: state: :nil, attr isn't empty"
e.some_attr = 'something' # some_attr is no longer nil
valid = UnwrappedValidate.(e, :nil)
refute("valid", valid)


p "===== NewReflection::UnwrappedValidate ====="
e = Example.new # some_attr is nil

# puts "\ntest: no state (expect :present), but attr is empty"
valid = NewReflection::UnwrappedValidate.(e)
refute("valid", valid)

# puts "\ntest: state: :present, but attr is empty"
valid = NewReflection::UnwrappedValidate.(e, :present)
refute("valid", valid)

# puts "\ntest: state: :nil and attr is empty"
valid = NewReflection::UnwrappedValidate.(e, :nil)
assert("valid", valid)

# puts "\ntest: no state (expect :present), attr isn't empty"
e.some_attr = 'something' # some_attr is no longer nil
valid = NewReflection::UnwrappedValidate.(e)
assert("valid", valid)

# puts "\ntest: state: :nil, attr isn't empty"
e.some_attr = 'something' # some_attr is no longer nil
valid = NewReflection::UnwrappedValidate.(e, :nil)
refute("valid", valid)

