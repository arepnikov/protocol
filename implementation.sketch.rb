require 'json'
require 'schema'
require 'openssl'

require_relative './init'

module Protocol
  Error = Class.new(StandardError)

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

class SomeClass
  module Substitute
    def self.build
      { k: '123' }
    end
  end
end

build = Protocol.get(SomeClass, :Substitute, :build)
p build.()

class SomeStruct
  include Schema::DataStructure

  attribute :some_attr, String
  attribute :some_other_attr, Integer

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

subject = SomeStruct.build(some_attr: "some value", some_other_attr: 11)

raw_data = Protocol.get(subject, :Transform, :raw_data)

# The subject will be supplied as a positional argument to the raw_data method
raw_data = raw_data.()
p raw_data

write = Protocol.get(subject, :Transform, :json, :write)

# Override the subject argument:
res = write.(raw_data)
p res

class SomeOtherClass
  module SomeConstant
    def self.some_method
    end
  end
end

subject = SomeOtherClass.new

begin
  Protocol.get(subject, :SomeConstant, :some_other_method)
rescue Protocol::Error => e
  p e
end
