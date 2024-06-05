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
  module Read
    def self.call(input, format_name, cls)
      transformer_reflection = transformer_reflection(cls)

      # transformer_reflection.subject == cls (Example)
      # transformer_reflection.target == Example::Transform
      format_reflection = transformer_reflection.get(format_name, coerce_constant: false)

      # format_reflection.subject == cls (Example)
      # format_reflection.target == Example::Transform::PrettyJSONFormat
      raw_data = format_reflection.(:read, input)

      instance = instance(raw_data, cls, transformer_reflection)
      instance

      # This time we also could solve it with two protocol methos:
      #
      # read_raw_data = Protocol.get(cls, :Transform, format_name, :read)
      # raw_data = read_raw_data.(input)
      #
      ### here we have a difficulty, '.instance' method has arity 1 or 2
      ### but it might be solve somehow :)
      #
      # build_instance = Protocol.get(cls, :Transform, :instance)
      # instance = build_instance.(raw_data)
    end

    def self.transformer_reflection(subject)
      # subject == cls (Example)
      Reflect.(subject, :Transform, strict: true)
    end

    def self.instance(raw_data, cls, transformer_reflection)
      ## possible interface:
      # transformer_reflection.(:instance, raw_data, cls, currying: false)

      transformer = transformer_reflection.target
      instance = get_instance(transformer, raw_data, cls)
      instance
    end

    def self.get_instance(transformer, raw_data, cls)
      method = transformer.method(:instance)

      instance = nil
      case method.parameters.length
      when 1
        instance = transformer.instance(raw_data)
      when 2
        instance = transformer.instance(raw_data, cls)
      end

      instance
    end
  end
end

module UnwrappedTransform
  module Read
    def self.call(input, format_name, cls)
      transformer_reflection = Reflect.(cls, :Transform, strict: true)

      format_reflection = transformer_reflection.get(format_name, coerce_constant: false)
      raw_data = format_reflection.(:read, input)

      transformer = transformer_reflection.target
      instance = get_instance(transformer, raw_data, cls)
      instance
    end

    # args = (1..9)
    # args.unshift(0) if curring
    # arity = 3
    # args.take(arity)
    # B.new.public_send(:test, *arg.take(arity))
    def self.get_instance(transformer, raw_data, cls)
      method = transformer.method(:instance)

      instance = nil
      case method.parameters.length
      when 1
        instance = transformer.instance(raw_data)
      when 2
        instance = transformer.instance(raw_data, cls)
      end

      instance
    end
  end
end

module NewReflection
  module UnwrappedTransform
    module Read
      def self.call(input, format_name, cls)
        # transformer_reflection = Reflect.(cls, :Transform, strict: true)
        transformer_reflection = PrimitiveReflection.new(cls, Example::Transform)

        # format_reflection = transformer_reflection.get(format_name, coerce_constant: false)
        # raw_data = format_reflection.(:read, input)
        format_reflection = PrimitiveReflection.new(cls, Example::Transform::PrettyJSONFormat)
        raw_data = format_reflection.(:read, input, currying: false)

        ## TODO: think what about this:
        ## for simplicity I ignored the fact that sometimes instance method might need 1 or 2 args
        ##
        # transformer = transformer_reflection.target
        # instance = get_instance(transformer, raw_data, cls)
        instance = transformer_reflection.(:instance, raw_data, currying: false)

        instance
      end
    end
  end
end

input = <<-JSON
{
  "some_attribute": "attribute"
}
JSON
input = input.strip # removes last new line after '}'

instance = Transform::Read.(input, :json, Example)
assert("instance.kind_of?(Example)", instance.kind_of?(Example))
assert("instance.some_attribute == 'attribute'", instance.some_attribute == 'attribute')

instance = SimpleTransform::Read.(input, :json, Example)
assert("instance.kind_of?(Example)", instance.kind_of?(Example))
assert("instance.some_attribute == 'attribute'", instance.some_attribute == 'attribute')

instance = UnwrappedTransform::Read.(input, :json, Example)
assert("instance.kind_of?(Example)", instance.kind_of?(Example))
assert("instance.some_attribute == 'attribute'", instance.some_attribute == 'attribute')

p "===== NewReflection::UnwrappedTransform ====="
instance = NewReflection::UnwrappedTransform::Read.(input, :json, Example)
assert("instance.kind_of?(Example)", instance.kind_of?(Example))
assert("instance.some_attribute == 'attribute'", instance.some_attribute == 'attribute')
