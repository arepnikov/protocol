#!/usr/bin/env -S ruby --disable-gems

require "tempfile"
ENV["GEM_HOME"] = Dir.mktmpdir("rubygems-#{File.basename($PROGRAM_NAME, ".rb")}")

require "rubygems" or abort "Invoke ruby with --disable-gems"
require "bundler/inline"

gemfile do
  source "https://rubygems.org"

  gem "evt-reflect", require: "reflect"

  group :development do
    gem "evt-schema", require: "schema"

    require 'json'
  end
end


module Protocol
  Error = Class.new(RuntimeError)

  def self.get(subject, namespace, *path, method_name)
    method = get_method(subject, namespace, *path, method_name)

    if method.arity.zero?
      method
    else
      proc { |arg| method.(arg || subject) }
    end
  end

  def self.get_method(subject, namespace, *path, method_name)
    # subject_namespace = Reflect.(subject, namespace)
    reflection = Reflect.(subject, namespace)
    subject_namespace = reflection.target

    receiver = traverse_path(subject_namespace, path)

    if receiver.respond_to?(method_name)
      receiver.method(method_name)
    else
      target_name = subject_namespace.name
      raise Error, "#{target_name} does not define method #{method_name}"
    end
  end

  private

  def self.traverse_path(subject_namespace, path)
    namespace = subject_namespace

    path.each do |path_segment|
      if path_segment.is_a?(Proc)
        namespace = path_segment.(namespace)

      elsif namespace.respond_to?(path_segment)
        namespace = namespace.public_send(path_segment)

      else
        target_name = namespace.name
        raise Error, "#{target_name} does not define method #{path_segment}"
      end
    end

    namespace
  end
end


## Construct a substitute by discovering the Substitute.build protocol
class SomeClass
  module Substitute
    def self.build
      SomeSubstitute.new
    end

    class SomeSubstitute
    end
  end
end

build = Protocol.get(SomeClass, :Substitute, :build)

substitute = build.()
p substitute
# => #<SomeClass::Substitute::SomeSubstitute:0x00000001066b9f48>


## Transform data structure into JSON via Transform protocol.
class SomeStruct < Struct.new(:some_attr, :some_other_attr)
  module Transform
    def self.json
      JSON
    end

    def self.raw_data(instance)
      instance.to_h
    end

    module JSON
      def self.write(raw_data)
        ::JSON.generate(raw_data)
      end
    end
  end
end

subject = SomeStruct.new(some_attr: 'some value', some_other_attr: 'some other value')

raw_data = Protocol.get(subject, :Transform, :raw_data)

## Subject is supplied to Transform.raw_data
raw_data = raw_data.()
p raw_data
# => {:some_attr=>"some value", :some_other_attr=>"some other value"}

write_json = Protocol.get(subject, :Transform, :json, :write)

## raw_data, rather than subject, is supplied to Transform::JSON.write
json = write_json.(raw_data)
p json
# => "{\"some_attr\":\"some value\",\"some_other_attr\":\"some other value\"}"


## Protocol error
class SomeOtherClass
  module SomeConstant
    def self.some_method
    end
  end
end

subject = SomeOtherClass.new

## Raises a Protocol::Error, since some_other_method isn't defined
Protocol.get(subject, :SomeConstant, :some_other_method)
# => SomeOtherClass::SomeConstant does not define method some_other_method (Protocol::Error)
