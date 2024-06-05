#!/usr/bin/env -S ruby --disable-gems

require "tempfile"
ENV["GEM_HOME"] = Dir.mktmpdir("rubygems-#{File.basename($PROGRAM_NAME, ".rb")}")

require "rubygems" or abort "Invoke ruby with --disable-gems"
require "bundler/inline"

require_relative "./primitive_reflection"

gemfile do
  source "https://rubygems.org"

  gem "evt-schema", require: "schema"
  require 'json'
end

class Example
  def some_instance_method
    "some_instance_method"
  end

  def some_other_instance_method(subject)
    "some_other_instance_method: with subject: '#{subject}'"
  end

  module SomeModule
    def self.arity_zero_method
      'arity_zero_method'
    end

    def self.some_method(subject, state='some default value')
      "some_method\n\tsubject: #{subject.inspect}\n\tstate (optional): #{state.inspect}"
    end
  end
end

e = Example.new
reflection = PrimitiveReflection.new(e, Example::SomeModule)

puts "\n===== actuate method with arity zero ====="
puts reflection.(:arity_zero_method, currying: false)
# => arity_zero_method

puts "\n===== actuate method with curried subject and without optional argument ====="
puts reflection.(:some_method)
# => some_method
#       subject: #<Example:0x00000001012c11c0>
#       state (optional): "some default value"

puts "\n===== actuate method with curried subject and with optional argument ====="
puts reflection.(:some_method, 'some provided optional argument')
# => some_method
#       subject: #<Example:0x00000001012c11c0>
#       state (optional): "some provided optional argument"

puts "\n===== actuate method with provided subject ====="
puts reflection.(:some_method, 'some provided subject', currying: false)
# => some_method
#       subject: "some provided subject"
#       state (optional): "some default value"

puts "\n===== actuate method with provided subject and optional argument ====="
puts reflection.(:some_method, 'some provided subject', 'some provided optional argument', currying: false)
# => some_method
#       subject: "some provided subject"
#       state (optional): "some provided optional argument"


puts "\n===== target could be an instance ====="
reflection = PrimitiveReflection.new(e, e)
puts reflection.(:some_instance_method, currying: false)
# => some_instance_method

puts "\n===== actuate with curried subject ====="
puts reflection.(:some_other_instance_method)
# => some_other_instance_method: with subject: '#<Example:0x00000001012c11c0>'

puts "\n===== actuate with provided argument ====="
puts reflection.(:some_other_instance_method, 'some value', currying: false)
# => some_other_instance_method: with subject: 'some value'
