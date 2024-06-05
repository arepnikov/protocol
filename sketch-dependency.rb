#!/usr/bin/env -S ruby --disable-gems

require "tempfile"
ENV["GEM_HOME"] = Dir.mktmpdir("rubygems-#{File.basename($PROGRAM_NAME, ".rb")}")

require "rubygems" or abort "Invoke ruby with --disable-gems"
require "bundler/inline"

require_relative "./primitive_reflection"

gemfile do
  source "https://rubygems.org"

  gem "evt-reflect", require: "reflect", path: "/Users/visuality/development/eventide_project/reflect/"
  gem "evt-attribute", require: "attribute"
  gem "evt-dependency", require: "dependency"#, path: "/Users/visuality/development/eventide_project/dependency/"
  # gem "evt-subst_attr", require: "subst_attr", path: "/Users/visuality/development/eventide_project/subst_attr/"

  gem "evt-schema", require: "schema"
  require 'json'
end

module SimpleSubstAttr
  module Attribute
    def self.define(target_class, attr_name, interface=nil, _record=nil)
      ::Attribute::Define.(target_class, attr_name, :accessor) do
        # SimpleSubstitute.build(interface)
        # UnwrappedSubstitute.build(interface)
        NewReflection::UnwrappedSubstitute.build(interface)
      end
    end
  end

  # without mimic
  # Substitute has to have build method
  module SimpleSubstitute
    extend self

    # record is for mimic, so it's redundant now
    def build(interface=nil, record=nil)
      substitute_module = substitute_module(interface)

      unless substitute_module.respond_to?(:build)
        raise 'Assumption: Substitute has build method'
      end

      substitute_module.send(:build)
    end

    def substitute_module(interface)
      constant_name = :Substitute

      reflection = Reflect.(interface, constant_name, strict: false, ancestors: true)

      if reflection.nil?
        return nil
      end

      mod = reflection.constant

      # Special case:
      # Including Substitute puts SubstAttr::Substitute
      # in the constant lookup class
      if mod.equal?(self)
        return nil
      end

      mod
    end
  end

  module UnwrappedSubstitute
    extend self

    # record is for mimic, so it's redundant now
    def build(interface=nil, record=nil)
      reflection = Reflect.(interface, :Substitute, strict: false, ancestors: true)
      substitute_module = reflection.constant
      substitute_module.send(:build)

      ## but if reflection could work with arity 0 then it would be possilbe:
      # reflection = Reflect.(interface, :Substitute, strict: false, ancestors: true)
      # reflection.call(:build)
    end
  end

  module NewReflection
    module UnwrappedSubstitute
      extend self

      # record is for mimic, so it's redundant now
      def build(interface=nil, record=nil)
        # reflection = Reflect.(interface, :Substitute, strict: false, ancestors: true)
        # substitute_module = reflection.constant
        # substitute_module.send(:build)
        reflection = PrimitiveReflection.new(interface, SomeDependency::Substitute)
        substitute_module = reflection.(:build, currying: false)
      end
    end
  end
end

module SimpleDependency
  def self.included(cls)
    cls.class_exec do
      extend Macro
    end
  end

  module Macro
    # dependency :some_dependency, SomeDependency
    def dependency_macro(attr_name, interface=nil, record: nil)
      Attribute.define(self, attr_name, interface, record)
    end
    alias :dependency :dependency_macro
  end

  module Attribute
    def self.define(receiver, attr_name, interface=nil, record=nil)
      SimpleSubstAttr::Attribute.define(receiver, attr_name, interface, record)
    end
  end
end

class SomeDependency
  def some_method
    'some value'
  end

  module Substitute
    def self.build
      Example.new
    end

    class Example
      def some_method
        'substituted value'
      end
    end
  end
end

class Example
  include SimpleDependency

  dependency :some_dependency, SomeDependency

  def configure
    self.some_dependency = SomeDependency.new
  end

  def call
    some_dependency.some_method
  end
end

example = Example.new
p example.()
example.configure
p example.()


