#!/usr/bin/env -S ruby --disable-gems

require "tempfile"
ENV["GEM_HOME"] = Dir.mktmpdir("rubygems-#{File.basename($PROGRAM_NAME, ".rb")}")

require "rubygems" or abort "Invoke ruby with --disable-gems"
require "bundler/inline"

require_relative "./primitive_reflection"

gemfile do
  source "https://rubygems.org"

  gem "evt-reflect", require: "reflect", path: "/Users/visuality/development/eventide_project/reflect/"
  gem "evt-transform", require: "transform"#, path: "/Users/visuality/development/eventide_project/validate/"

  gem "evt-schema", require: "schema"
  require 'json'
end

def assert(details, result)
  case result
  when true   then puts "asserted #{details}"
  when false  then puts "EXPECTED TO BE ASSERT: (#{details}) but it is not"
  else raise 'unsupported'
  end
end

class Example
  attr_accessor :some_attribute

  module Transform
    def self.json
      PrettyJSONFormat
    end

    def self.instance(raw_data)
      instance = Example.new
      instance.some_attribute = raw_data[:some_attribute]
      instance
    end

    def self.raw_data(instance)
      { some_attribute: instance.some_attribute }
    end

    module PrettyJSONFormat
      def self.read(json)
        JSON.parse(json, symbolize_names: true)
      end

      def self.write(raw_data)
        JSON.pretty_generate(raw_data)
      end
    end
  end
end

module SimpleTransform
  module Write
    def self.call(input, format_name)
      transformer_reflection = transformer_reflection(input)

      format_reflection = transformer_reflection.get(format_name, coerce_constant: false)

      raw_data = raw_data(input, transformer_reflection)

      output = format_reflection.(:write, raw_data)
      output
    end

    def self.transformer_reflection(subject)
      Reflect.(subject, :Transform, strict: true)
    end

    def self.raw_data(instance, transformer_reflection)
      transformer = transformer_reflection.target

      raw_data = transformer.raw_data(instance)
      raw_data
    end
  end
end

module UnwrappedTransform
  module Write
    def self.call(input, format_name)
      transformer_reflection = Reflect.(input, :Transform, strict: true)

      # format_name == :json
      format_reflection = transformer_reflection.get(format_name, coerce_constant: false)

      transformer = transformer_reflection.target
      raw_data = transformer.raw_data(input)

      output = format_reflection.(:write, raw_data)
      output
    end
  end
end

module AlteredOnceTransform
  module Write
    def self.call(input, format_name)
      transformer_reflection = Reflect.(input, :Transform, strict: true)

      ## this looks redundant, since reflection actuator does this
      ## and it's subject == input
      #
      # transformer = transformer_reflection.target
      # raw_data = transformer.raw_data(input)

      # Versio ONE:
      # raw_data = transformer_reflection.call(:raw_data, input)

      # Version TWO: Currying subject
      raw_data = transformer_reflection.call(:raw_data)

      # format_name == :json
      # traversing: from 'input' to [:Transform, :json]
      format_reflection = transformer_reflection.get(format_name, coerce_constant: false)
      output = format_reflection.(:write, raw_data)
      output

      # So we have two reflections:
      # 1. accesses Transform#raw_data method and can use currying
      # 2. accesses Transform.json.write method, but it keeps curried subject, so it couldn't be used
      # which it theory could be solved with Protocol in sketch.rb
    end
  end
end

module NewReflection
  module UnwrappedTransform
    module Write
      def self.call(input, format_name)
        # transformer_reflection = Reflect.(input, :Transform, strict: true)
        transformer_reflection = PrimitiveReflection.new(input, Example::Transform)

        # format_reflection = transformer_reflection.get(format_name, coerce_constant: false)
        format_reflection = PrimitiveReflection.new(input, Example::Transform::PrettyJSONFormat)

        # transformer = transformer_reflection.target
        # raw_data = transformer.raw_data(input)
        raw_data = transformer_reflection.call(:raw_data)

        # output = format_reflection.(:write, raw_data)
        output = format_reflection.(:write, raw_data, currying: false)

        output
      end
    end
  end
end

e = Example.new
e.some_attribute = "attribute"

expected = <<-JSON
{
  "some_attribute": "attribute"
}
JSON
expected = expected.strip # removes last new line after '}'


transformed = Transform::Write.(e, :json)
assert("transformed == expected", transformed == expected)

transformed = SimpleTransform::Write.(e, :json)
assert("transformed == expected", transformed == expected)

transformed = UnwrappedTransform::Write.(e, :json)
assert("transformed == expected", transformed == expected)

transformed = AlteredOnceTransform::Write.(e, :json)
assert("transformed == expected", transformed == expected)

p "===== NewReflection::UnwrappedTransform ====="
transformed = NewReflection::UnwrappedTransform::Write.(e, :json)
assert("transformed == expected", transformed == expected)
